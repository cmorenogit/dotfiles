---
name: improve-codebase-architecture
description: Rescatá un codebase que se volvió "ball of mud" — detecta módulos shallow, los presenta como reporte visual anotable con /lavish, y te lleva a re-diseñar el que elijas hacia un deep module. Solo a mano (/improve-codebase-architecture).
disable-model-invocation: true
---

# Improve Codebase Architecture

Sacá a la superficie la fricción arquitectónica y propuso **deepening opportunities** — refactors que convierten módulos shallow en deep. El objetivo es **testabilidad** y **navegabilidad para la IA**. Recomendado: correrlo sobre el codebase cada pocos días.

Este comando está _informado_ por el modelo de dominio del proyecto y construido sobre un vocabulario de diseño compartido:

- Invocá el skill **`/codebase-design`** para el vocabulario de arquitectura (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) y sus principios (el deletion test, "la interfaz es la superficie de test", "un adapter = seam hipotético, dos = real"). Usá estos términos **exacto** en cada sugerencia — no derives a "component", "service", "API" ni "boundary".
- El lenguaje de dominio en `CONTEXT.md` les da nombre a los buenos seams; los ADRs en `docs/adr/` registran decisiones que este comando **no debe re-litigar**.

## Proceso

### 1. Explore

Leé primero el glosario de dominio (`CONTEXT.md`) y cualquier ADR del área que vayas a tocar.

Después usá la herramienta Agent con `subagent_type=Explore` para caminar el codebase. No sigas heurísticas rígidas — explorá orgánicamente y anotá dónde experimentás fricción:

- ¿Entender un concepto obliga a rebotar entre muchos módulos chicos?
- ¿Dónde hay módulos **shallow** — interfaz casi tan compleja como la implementación?
- ¿Dónde se extrajeron funciones puras solo por testabilidad, pero los bugs reales se esconden en cómo se las llama? (sin **locality**)
- ¿Dónde módulos fuertemente acoplados se filtran a través de sus seams?
- ¿Qué partes del codebase están sin testear, o son difíciles de testear a través de su interfaz actual?

Aplicá el **deletion test** a todo lo que sospeches shallow: ¿borrarlo concentraría la complejidad, o solo la movería? Un "sí, concentra" es la señal que buscás.

### 2. Presentá los candidatos como reporte visual con `/lavish`

Construí el reporte con el skill **`/lavish`**: un artefacto HTML que César ve y **anota** en el navegador (reemplaza el HTML estático). Nada toca el repo — vive en el scratchpad de la sesión.

Sé visual. Usá before/after por candidato; diagramas donde un grafo comunica mejor que prosa. Por cada candidato, una **card** con:

- **Files** — qué archivos/módulos están involucrados
- **Problem** — por qué la arquitectura actual genera fricción
- **Solution** — en lenguaje simple, qué cambiaría
- **Benefits** — explicado en términos de **locality** y **leverage**, y cómo mejorarían los tests
- **Before / After** — lado a lado, ilustrando la shallowness y la profundización
- **Recommendation strength** — una badge: `Strong`, `Worth exploring` o `Speculative`

Cerrá el reporte con una sección **Top recommendation**: cuál atacarías primero y por qué.

**Usá el vocabulario de `CONTEXT.md` para el dominio, y el de `/codebase-design` para la arquitectura.** Si `CONTEXT.md` define "Order", hablá del "módulo de Order intake" — no del "FooBarHandler", ni del "Order service".

**Conflictos con ADR**: si un candidato contradice un ADR existente, sacalo a la superficie solo cuando la fricción sea real como para reabrir el ADR. Marcalo claro en la card (un callout de advertencia: _"contradice ADR-0007 — pero vale reabrir porque…"_). No listes cada refactor teórico que un ADR prohíbe.

**No propongas interfaces todavía.** Una vez abierto el reporte en `/lavish`, dejá que César anote/elija el candidato a explorar (o preguntale: "¿cuál querés explorar?").

### 3. Grilling loop

Cuando César elige un candidato, recorré con él el árbol de diseño — constraints, dependencias, la forma del módulo profundizado, qué vive detrás del seam, qué tests sobreviven.

Interrogatorio (mismas reglas que `/grill`; lo inlineamos porque este skill es user-invoked y no puede invocar otro user-invoked):

- **Una pregunta a la vez.** Esperá la respuesta antes de seguir.
- **Cada pregunta lleva tu respuesta recomendada** + el porqué en una línea.
- **Si la pregunta se contesta explorando el código, explorá** en vez de preguntar.
- **Ordená por dependencia:** primero las decisiones que condicionan a otras.

Los side-effects de dominio ocurren **inline** a medida que las decisiones cristalizan — no los acumules:

- **¿Nombrás el módulo profundizado con un concepto que no está en `CONTEXT.md`?** Agregá el término a `CONTEXT.md`. Creá el archivo de forma lazy si no existe. `CONTEXT.md` es un glosario y nada más — sin detalles de implementación.
- **¿Afinás un término difuso durante la charla?** Actualizá `CONTEXT.md` ahí mismo.
- **¿César rechaza el candidato con una razón load-bearing?** Ofrecé un ADR — solo cuando las **tres** condiciones se cumplen: (1) **difícil de revertir**, (2) **sorprendente sin contexto** (un lector futuro se preguntaría "¿por qué lo hicieron así?"), (3) **resultado de un trade-off real**. Enmarcalo: _"¿Lo grabo como ADR para que futuras revisiones no re-sugieran lo mismo?"_ Si falta cualquiera de las tres, salteá el ADR.
- **¿Querés explorar interfaces alternativas para el módulo profundizado?** Invocá `/codebase-design` y usá su patrón **design-it-twice** (sub-agentes en paralelo) de `DESIGN-IT-TWICE.md`.
