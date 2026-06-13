---
name: product-lens
description: >
  Evaluación con DOBLE LENTE — producto + técnica — de cualquier objeto evaluable:
  propuesta, análisis, PR, issue o respuesta de Linear. Aplica el Product Decision Canon
  (SVPG + doctrina Apprecio + memoria RYR): 4 riesgos, outcome vs output, coherencia OST,
  integridad de priorización (RICE/theater check), canje/equidad, dependencias bloqueantes
  y plan a producción. El lente técnico emite veredicto (lane de César); el de producto es
  conciencia advisory (scope decide Nicole). NUNCA postea (César publica). Diseñado para
  integrarse al flujo linear-* (gate B2). Triggers: "/product-lens", "revisá esta
  propuesta", "aplicá el canon de producto", "lente de producto a <doc|issue|PR>",
  "evaluá esto con doble lente".
license: MIT
metadata:
  author: cesar-moreno
  version: "2.0"
---

# product-lens — evaluación con doble lente (producto + técnica)

## Propósito

César decide en el **lane técnico**, pero ninguna evaluación suya es ciega a producto:
la conciencia de producto informa el juicio técnico, aunque el scope lo decida Nicole y
la prioridad Ignacio. Este skill estructura esa doble mirada para CUALQUIER objeto
evaluable — no solo "propuestas de producto".

El deliverable es **la evaluación** (veredicto + hallazgos + recomendación). Este skill
NO postea en Linear, NO edita el objeto evaluado, NO decide scope ni merge ni severidad QA.

## Fuente de verdad (cargar SIEMPRE, en este orden de autoridad)

1. **Canon:** `~/Code/_vault/_work/apprecio/_shared/product-decision-canon.md` — jerarquía de 4 capas (libros > vault > engram RYR > docs puntuales), kernel mínimo y checklist de 20 preguntas. Ante conflicto entre capas, gana la superior.
2. **Perfil del decisor:** `~/Code/_vault/_work/apprecio/linear/knowledge/ignacio-product-profile.md` — para ALINEAR, nunca para hablar por él.
3. **Lecciones vigentes:** `~/Code/_vault/_work/apprecio/linear/knowledge/linear-review-lessons.md` — advisory; jamás para reabrir decisiones cerradas.

Regla de precedencia (igual que linear-contract B3): vault canónico gana sobre engram; engram es cache best-effort.

## Flujo

### 0. Clasificar el objeto → modo de evaluación

| Objeto | Lente de producto | Lente técnico |
|---|---|---|
| **Propuesta / análisis de producto** (OST, priorización, scope) | A FONDO — checklist completo | A FONDO — viabilidad de cada pieza comprometida |
| **PR / cambio técnico** | KERNEL — las 6 preguntas mínimas del canon | A FONDO — el veredicto principal |
| **Respuesta / decisión liviana** (pregunta puntual, acuse, routing) | KERNEL mental — solo se reporta si algo dispara | Proporcional al riesgo |

Si el objeto no tiene decisión de producto NI riesgo técnico (typo, doc, acuse), decirlo
y no forzar el canon. Los fixes FSV rutinarios no pasan por acá.

### 1. Contexto (obligatorio si hay ISSUE-ID)

- **Vault:** `~/Code/_vault/_work/apprecio/projects/<slug>/issues/<ID>/` — triage, reviews y propuestas previas. Una evaluación que ignora la revisión anterior pierde las decisiones ya tomadas.
- **Linear:** hilo del issue — decisiones cerradas, pivots comunicados, el **encargo** original (alcance, ventana, validadores). El objeto se evalúa contra el encargo, no contra un ideal abstracto.
- **Engram del proyecto:** `mem_search(project: "recognition-and-rewards", query: <keywords>)` para RYR; el proyecto que corresponda para otros teams. Sin memoria → seguir sin ella, declarándolo.

### 2. Verificaciones mecánicas (antes de opinar — ambos lentes las comparten)

- **Aritmética de priorización:** recalcular cada fila RICE/ICE. Errores invalidan el orden.
- **Confidence ↔ evidencia:** ¿cada confidence corresponde al tipo de evidencia (data > prototipo > entrevistas > opinión)?
- **Consistencia interna:** piezas en el árbol/tabla ausentes del compromiso (o viceversa), scores altos descartados en silencio, leyendas que contradicen el texto.
- **Dependencias bloqueantes:** cruzar cada pieza comprometida contra dependencias conocidas (gobernanza observe/enforce, presupuesto, datos inexistentes, issues bloqueantes). Pieza bloqueada en compromiso firme = bloqueante.
- **Claims técnicos decisivos:** toda afirmación de código que sostiene una decisión se verifica en la fuente (`ruta:línea`) o se marca ❓ — nunca ⚠️/✅ sin trazar (doctrina RYR-112).
- **Decisiones cerradas:** cruzar contra el hilo. Contradecir una decisión cerrada sin reconocerla = hallazgo. NUNCA reabrir una cerrada como hallazgo propio (anti-patrón RYR-83).

### 3. Lente de producto (advisory — conciencia, no veredicto de scope)

Aplicar el checklist del canon según el modo (completo o kernel). Para cada fallo:
`pregunta # · evidencia (cita o ausencia) · severidad`.

**Fraseo obligatorio:** los hallazgos de producto se redactan como **insumo para el dueño
del scope** ("esto le falta a la propuesta para que Nicole pueda decidir X"), o como
pregunta abierta con dueño nombrado — nunca como veredicto de alcance. El lente de
producto ilumina; no decide.

### 4. Lente técnico (decisorio — el lane de César)

- **Feasibility real por pieza:** viable (S/M/L) / condicional (a qué) / bloqueada (por qué) — tabla, no prosa.
- **Riesgo técnico:** seguridad (tenant isolation, RLS, permisos vs estructura real), dinero (idempotencia, doble-grant, caps), datos (campos que no existen), arquitectura (¿pasa por el choke point/RPC canonical o bypasea? "el candado autoriza, la feature obedece").
- **Estado B:** ¿algo se declara "hecho" que está construido pero no activado/conectado?
- **Plan a producción:** secuencia técnica, coordinación con owners, QA, criterios de evaluación, rollout observe→enforce con monitoreo. Sin esto, el encargo no cierra.
- Si hay código/PR: veredicto `APPROVE / CONDITIONS / CHANGES` + `MUST/SHOULD/CONSIDER` con `archivo:línea` (mismo formato que pr-review/gate B2).

### 5. Producir la evaluación

```
## Veredicto: <una línea — publicable / no publicable aún / viable / bloqueado / replantear>

### Qué está bien (el review es coaching — reconocer el método antes de exigir)

### Lente técnico (mi lane)
| Pieza/aspecto | Veredicto | Evidencia |
+ MUST/SHOULD/CONSIDER si hay código

### Lente de producto (insumo para el dueño del scope)
| # canon | Gap | Para quién |

### Recomendación
1-4 pasos concretos. Si el alcance está mal, proponer recorte como decisión binaria
(mantener vs reducir), no como menú. Cerrar con "Tu chequeo (30s-2min)": lo que solo
César debe verificar antes de usar/publicar la evaluación.
```

Reglas: liderar con el outcome de la evaluación; cada hallazgo cita evidencia; claims
sin verificar no entran; máx 3-5 bloqueantes priorizados, el resto agrupado. Si el
resultado va a Linear: pre-flight de comentario (reply con `parentId`, @menciones de los
validadores del encargo, call to action).

### 6. Cierre

- Regla durable nueva → proponer `/linear-learn` (único punto de captura; este skill no escribe lessons).
- `mem_save` si hubo decisión o descubrimiento no obvio.
- Persistir la evaluación en vault vía `/vault-save` solo si César lo pide (destino: carpeta del issue).

## Integración con el flujo linear-* (siguiente paso — puntos de enganche definidos)

Este skill está diseñado para que `linear-*` lo consuma sin reescribirlo:

| Punto de enganche | Cómo |
|---|---|
| **GAUGE (B1)** | Nueva señal de ruteo: objeto = propuesta/análisis de producto (OST, priorización, scope) → lane `product-lens` (hoy el gauge solo distingue trivial/acotado/sustancial para código) |
| **Gate B2 de `/linear-respond`** | El canon se vuelve fuente citable del gate para drafts en modo PROPUESTA: el evaluador independiente corre el **kernel** (6 preguntas) + theater-check con salida `{pass\|fail\|N/A, evidencia}` por criterio — mismo schema que los 8 criterios actuales |
| **Alertas B6 de `/linear-today`** | Las preguntas del canon extienden las señales existentes (flujo invertido, decisión sin decisor) con: pieza bloqueada comprometida (#16), priorización post-hoc (#12), compromiso sin plan a producción (#18) |
| **Memoria B3** | Canónico vault: `_shared/product-decision-canon.md` · espejo engram: `product/decision-canon-y-skill-product-lens` · `applies_to: all` (capas 1-2) / `rr` (capas 3-4) · `last_confirmed` se actualiza vía `/linear-week` |

Reglas heredadas del contrato al integrarse: never-post, fail-closed, vigencia
(`last_confirmed` > 90 días → advisory degradado), aplicabilidad por proyecto.

## Anti-patrones de este skill

- Emitir veredicto de scope/prioridad/severidad desde el lente de producto (eso invade el lane de Nicole/Ignacio/Julieth).
- Reescribir la propuesta sin que lo pidan (el deliverable es la evaluación).
- Aplicar el checklist como burocracia a objetos sin decisión de producto ni riesgo.
- Simular a Ignacio/Nicole o predecir "qué dirían" — el perfil alinea criterios, no pone palabras en bocas.
- Citar un claim de código sin `ruta:línea` verificada.
