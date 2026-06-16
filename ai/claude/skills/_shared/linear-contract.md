# Linear Contract — bloques compartidos del sistema `linear-*`

> **Fuente única.** Los comandos `linear-*` activos (**today, respond, learn**; `update`/`week` aún no construidos) **referencian** este archivo en vez de re-describir su maquinaria. Si una regla vive acá, NO se re-escribe en cada skill.

---

## Núcleo de guardrails (generales — pocos, estables, aplican SIEMPRE)

1. **Never-post.** Ningún comando `linear-*` postea en Linear. Redacta; César publica. **Enforcement nivel 4 ACTIVO:** hook PreToolUse (`~/.claude/hooks/linear-write-guard.sh`) fuerza confirmación humana en todo `save_comment`/`save_issue`/`delete_comment`.
2. **Fail-closed.** Si un paso se omite o falla, pasa lo seguro por default: sin PASS explícito del gate → **no publicable**; ante la duda → 🟡, nunca silencio.
3. **Gate antes de publicar.** Todo borrador pasa por B2·gate. Sin veredicto de gate → no publicable.
4. **Dedup de memoria.** Toda escritura a engram usa `topic_key` (upsert mecánico) precedido de `mem_search` + lectura del canónico vault (este paso es convención — nivel 2, no 3). 1 regla = 1 observación.

---

## Contexto de proyecto (applicability gate) — OBLIGATORIO antes de análisis pesado

El motor de review (`pr-review` + su registry) está **tuneado a R&R** (`apprecio-pulse`: Supabase, RLS, `manager_id`, edge functions). Aplicarlo a otro codebase produce falsos MUST FIX o findings perdidos.

**1. Detectar proyecto** (determinístico, por señales en orden):

| Señal | Proyecto |
|---|---|
| Team `RYR` / labels Beat·Rewards / repos `apprecio-pulse`·`ryr-39255` | `rr` |
| Team `App` | `app` |
| Team `Platform` + repo/label fuerza · sl · engagement | `fuerza` / `sl` / `engagement` |
| No determinable | `unsupported` |

**2. Rutear:**
- `rr` → pipeline completo (pr-review + registry + filtro Ignacio).
- Cualquier otro → **DEGRADAR explícito**: "review manual — contexto preparado (issue+hilo+diff resumido), SIN veredicto automático; el pipeline no está tuneado a este repo". Nunca aplicar heurísticas/detection-rules de R&R fuera de R&R.

**3. Conocimiento filtrado por proyecto:** criterios y lecciones llevan `applies_to:` (`rr` | `all` | lista). El gate **solo cita una regla si su `applies_to` matchea** el proyecto actual.

---

## B1 · Scan — detección + clasificación

Ejecutá el motor de **`linear-mention-triage`** como **paso interno** (NO como skill independiente — el comando standalone queda **deprecado**; `today` es la única vía de entrada diaria). Del SKILL.md del triaje: Reglas rectoras + §1 detectar + §2 clasificar (🔴/🟡/descartado, por issue). `--watch` es opt-in, fuera del default. No reescribas esa lógica (ganó robustez tras RYR-6/82/83/87).

**Artefactos (formatos distintos, no confundir):**
- `scan-index.md` — registro histórico de detección, 3 columnas `| issue | último comentario de César (fecha) | nota |`. Es metadato, NO veredicto ni autorización de skip.
- `today-{fecha}.md` — cola del día, 5 columnas `| issue | lane | gauge | estado | nota |` + bloque de telemetría (ver B5).

Usan B1: `today`, `week`.

### GAUGE — profundidad de un review (compartido)
Con metadata del PR (`gh pr view` — files+diffstat, **sin checkout**). Leé `review/issue/{ID}/gate` si hubo decisión previa.

| Nivel | Señales (cualquiera) | Ruta |
|---|---|---|
| **Trivial / no-código** | pregunta/decisión/acuse/routing; o solo tests/docs/typo/rename/lint/config | respuesta liviana, NO pipeline |
| **Acotado** | 1 módulo, 1 concern, sin superficie de riesgo | review pesado de 1 dimensión |
| **Sustancial** | lógica de negocio, varios módulos, riesgo (`supabase/functions`, migraciones, auth/RLS, manager/dept/team), cross-cutting | review pesado completo |

**Regla de riesgo concentrado (override por contenido):** si el diff —por chico que sea— toca **autorización, `tenant_id`, RLS, checks de permisos o comparaciones de límites**, escala MÍNIMO a sustancial. El tamaño nunca baja el nivel de un cambio de seguridad.
**Ante la duda, subí un nivel. Muestra + confirmá** antes de gastar pipeline.

---

## B2 · Spine — draft + gate + present

**Orden del borrador** (siempre): 📖 de qué se trata → 🎯 qué respondés y por qué → borrador → veredicto (si review: `APPROVE/CONDITIONS/CHANGES` + `MUST/SHOULD/CONSIDER` con `archivo:línea`) → ⚠️ advertencias. Confiado, lean, español.

**Dos modos de apertura (lección 10/06, doctrina Ignacio/Nicole):**
- **PROPUESTA** (plantear un curso de acción) → el PROBLEMA va primero, **en términos de negocio/usuario** ("qué está mal y a quién le duele"), luego comportamiento esperado → opciones con esfuerzo → recomendación razonada → decisor nombrado. Nunca abrir con la solución técnica.
- **RESPUESTA puntual** (te preguntaron algo) → la respuesta va primero; el contexto después. Responder lo que se pregunta.

**Gate (validación final con ojos frescos — 3 filtros, 3 anillos).** Ningún borrador se muestra sin pasar el **gate §3.5 del triaje**, corrido por un evaluador independiente que devuelve por criterio `{pass|fail|N/A, evidencia}`. Los criterios se agrupan en los **3 filtros del `outcome.md`**: **Filtro 1 PERTINENCIA es un PRE-GATE** (P1-P4: mención real · pedida bien formada · le toca a César · sigue abierta) que corre PRIMERO sobre TODA mención — si falla, el borrador correcto es no-responder / devolución / ruteo, y no se evalúa el contenido; **Filtro 2 CALIDAD** (criterios 1,2,3,5,6,7 + 10 idioma); **Filtro 3 CREDIBILIDAD** (4 lane · 8 no-reabrir · R3 no-falsa-autoridad). El gate corre en **3 anillos** (ver `outcome.md`): **anillo 1** = este evaluador Claude **fresco** —recibe el borrador como artefacto + los hechos crudos, NUNCA el razonamiento del redactor— corre los 3 filtros (siempre); **anillo 2** = cross-model `pi`/gpt-5.5 sobre forma/idioma (Criterios 6+10), **solo en GAUGE pesado**, consenso fail-closed con el anillo 1 (ante discrepancia gana el más estricto); **anillo 3** = `verify-citations.sh` determinístico (Criterio 5). Ajustes que PRIMAN sobre el texto del triaje:
- **Fuente de criterios:** `ignacio-review-criteria.md` (canónico) — NO `ignacio-product-profile.md` (ese es contexto de prioridades, complemento).
- **Lente de producto (kernel):** todo draft en **modo PROPUESTA** (o que responda a una propuesta) corre además el **kernel K1-K6** del Product Decision Canon (`~/Code/_vault/_work/apprecio/_shared/product-decision-canon.md`) — mismo schema `{pass|fail|N/A, evidencia}`, mismas reglas de vigencia/aplicabilidad. Los FAIL de producto se reportan como **insumo para el dueño del scope**, nunca como veredicto de alcance. Propuesta/análisis de producto completo → el GAUGE rutea a `/product-lens` (checklist de 20). Si una lección local choca con la capa 1 del canon → se cita CON su matiz (tabla de tensiones del canon).
- **Precedencia:** si engram y vault difieren → **gana el vault** (engram es cache best-effort, puede estar stale).
- **Vigencia:** al citar un criterio/lección, incluir su fecha. Si `last_confirmed` > 90 días → se cita como **soft/advisory degradado**, nunca como bloqueante.
- **Aplicabilidad:** solo citar reglas cuyo `applies_to` matchee el proyecto (ver Contexto de proyecto).
- **Criterio 8** (no reabrir decisión cerrada / no contradecir lo que César validó) — la cura de RYR-83. Advisory que se cita, jamás regla que reabre.
- **Pre-gate P2** (pedida bien formada — ex-criterio 9, la cura de RYR-111, 11/06): el pre-gate de pertinencia generaliza esto a TODA mención. Para *review formal*, P2 falla si (a) el **comentario de la solicitud** no menciona a **@juli** (QA siguiente) y a **@ignacio** (revisión/merge), o (b) el issue no está en **`In Review`** → NO se emite veredicto; devolución de proceso señalando qué falta. El estado lo valida ADEMÁS el hook (`linear-write-guard.sh` v2: API en vivo si hay `LINEAR_API_KEY`, si no snapshot `~/.claude/cache/linear-state/{ID}.json` que persiste el pre-flight de `respond`; fail-closed → ⚠️ en el permission prompt).
- **Citas verificadas (nivel 3 ACTIVO):** antes del veredicto final, correr `~/.claude/skills/_shared/scripts/verify-citations.sh <borrador> <repo-clone> <ref>`. **Cualquier FAIL → el APPROVE degrada a CONDITIONS** con ⚠️ cita no verificable. El LLM valida la forma; el script valida la evidencia.

**Anti-stale (borradores de proceso/decisión):** si el draft responde un tema de proceso o una decisión y el último comentario del hilo es anterior a un meeting reciente del equipo → chequear la transcripción en Drive (o advertir "⚠️ posible decisión fuera de Linear — verificá si el weekly lo tocó"). Lección RYR-75: las decisiones viajan por canales que Linear no registra.

**Resolución fail-closed:** todos PASS/N-A → ✅; FAIL de contenido → reescribe ≤2 vueltas; sin resolver → **⚠️ no publicable**. Nunca PASS implícito.

**Re-gate sobre ediciones (lección 10/06 — falso negativo real):** si César edita el borrador después del gate, la versión FINAL se re-cruza contra los criterios antes de publicar. Si una edición introduce una violación (ej. quitar la recomendación → viola criterio #9 de Ignacio "sin recomendación está incompleto"), se le **advierte citando el criterio** — él decide igual (puede publicar), pero informado. El gate valida la versión que sale, no la que se redactó.

**Al presentar (verificación humana proporcional):** todo borrador cierra con un bloque **"Tu chequeo (30s-2min)"** — los 1-3 puntos que SOLO César debe verificar antes de publicar, proporcional a la consecuencia: veredicto APPROVE/CHANGES → leer la evidencia citada; acuse liviano → lectura rápida. El ✅ del gate reduce el trabajo de César al juicio final; nunca lo reemplaza.

Usan B2: `respond` (y `update` cuando exista).

---

## B3 · Memoria — vault canónico, engram cache

**Regla de oro:** el **vault (ruta absoluta)** es la verdad — cwd-independiente. Engram es acelerador best-effort (`scope: personal`, cross-project). Si difieren → vault gana. Nunca cachear estado vivo (diff, PR abierto, `file:línea`) como verdad.

| Conocimiento | Canónico (vault) | Espejo engram |
|---|---|---|
| Criterios Ignacio | `~/Code/_vault/_work/apprecio/linear/knowledge/ignacio-review-criteria.md` | `review/ignacio/criteria` |
| Lecciones | `~/Code/_vault/_work/apprecio/linear/knowledge/linear-review-lessons.md` | `review/lessons/{slug}` |
| Patrones del equipo (errores recurrentes de cualquiera) | ídem, sección "Team patterns" | `review/team-patterns/{slug}` |
| Canon de decisión de producto (kernel K1-K6 + checklist 20 + tensiones) | `~/Code/_vault/_work/apprecio/_shared/product-decision-canon.md` | `product/decision-canon-y-skill-product-lens` |
| Decisión gauge/gate por issue | `~/Code/_vault/_work/apprecio/projects/<slug>/issues/{ID}/triage.md` (sección "Gate"; slug por prefijo: RYR→rr) | `review/issue/{ID}/gate` |
| Contexto rápido PR | ídem (sección "PR") | `review/issue/{ID}/pr-summary` |
| Estado del día | `~/Code/_vault/_work/apprecio/linear/today/today-{fecha}.md` + `linear/scan-index.md` | `linear/today/{fecha}` |

> **Casa única del sistema:** todo artefacto del sistema `linear-*` vive bajo `~/Code/_vault/_work/apprecio/linear/` (knowledge/ · today/ · scan-index.md · system/), EXCEPTO lo per-issue, que vive en la carpeta del issue (`projects/<slug>/issues/{ID}/`) — regla de detección del CLAUDE.md del vault. Las rutas viejas (`triage/`, `_shared/ignacio-*`, `_shared/linear-review-lessons.md`) están retiradas y el hook del vault las bloquea.

Metadata obligatoria en criterios/lecciones: `applies_to:` + `last_confirmed:` (la pone `learn`; el gate la exige para citar como bloqueante).

**Política de conocimiento (gobernanza):**
- **Puerta única:** `linear-review-lessons.md` es la entrada (índice arriba del archivo). ESCRIBEN solo `learn` y `week` (dedup centralizado); los demás comandos LEEN y citan.
- **Test de entrada a lecciones:** "¿cambia cómo reviso/respondo el mes que viene?" Si no → NO es lección (es estado → `weekly/{W}/estado.md`).
- **Promoción:** weekly/meetings = materia prima que caduca; `week` promueve lo durable a lecciones/criterios y archiva el resto en el estado semanal. Nunca acumular decisiones coyunturales en los archivos curados.
- **Formato de toda entrada:** Regla → Por qué → Cómo aplicarla en review → Origen (ref) → `applies_to` + `last_confirmed`.

Usan B3: TODOS.

---

## B4 · Learn — destilar + deduplicar + rutear

Único punto de captura (los demás comandos **sugieren** `/linear-learn`). Destila la regla durable + "cómo aplicarla" + **`applies_to` + `last_confirmed`** → dedup (`mem_search` + canónico vault + `topic_key`) → rutea (lección → lessons; criterio Ignacio → criteria; check de código particular → **registry**). Conflict-surfacing protocol de `CLAUDE.local.md`.

Usan B4: `learn`; lo invoca `week` (cuando exista).

---

## B6 · Alertas de flujo — gaps de producto/proceso (advisory)

El sistema no solo detecta "qué me piden" — detecta **qué se está rompiendo en el flujo** (feedback César 11/06, caso RYR-119: el scope pivoteó 3 veces en 24h con dev arrancando ese día). Las señales se fundan en los criterios canónicos ya capturados (`ignacio-review-criteria.md` + lessons: outcome-first, decisor nombrado, alternativas con esfuerzo, estado=realidad):

| Señal | Detección | Ejemplo real |
|---|---|---|
| **Scope churn** | el alcance cambió ≥2 veces en la ventana sin confirmación del decisor | RYR-119 11/06: CRUD+cron → cron → tramos en <24h |
| **Deadline vs definición** | fecha comprometida con alcance aún abierto y la ventana de dev consumiéndose | RYR-119: plan "dev mié-vie", miércoles y sin scope confirmado |
| **Flujo invertido** | la propuesta parte de la solución y justifica hacia el outcome (doctrina Nicole/Ignacio: outcome primero, la solución cae sola) | RYR-119 propuesta v1/v2 (lo marcó Nicole `86ff31b4`) |
| **Claim técnico decisivo sin verificar** | una decisión de scope se apoya en una afirmación de código no verificada — cruzar contra issues/hilos conocidos | «hire_date ya existe en el motor» vs RYR-120 «el seam no calcula años» |
| **Decisión sin decisor** | hay opciones sobre la mesa y nadie nombrado para decidir, o el owner del próximo paso es implícito | criterio #2 de Ignacio |
| **Priorización post-hoc** | scores (RICE/ICE) como justificación de una decisión ya tomada: números sin fuente, score alto descartado en silencio (canon #12) | RYR-119 v4: M-A3 (75) fuera sin mención; confidence sin evidencia |
| **Pieza bloqueada comprometida** | el compromiso incluye una pieza con dependencia dura (gobernanza, presupuesto, dato inexistente) sin condición explícita (canon #16) | RYR-119 v4: aguinaldo con gobernanza en `observe` |
| **Compromiso sin plan a producción** | alcance comprometido sin secuencia técnica / QA / criterios de evaluación (canon #18) | RYR-119 v4: sin "cómo se verifica" ni entrega |

**Anti-ruido (estricto):** máx **3 alertas por tick**, solo de alta confianza, solo en issues donde César tiene rol (owner técnico, mentor, mencionado, o su scope). Formato por alerta: **cita textual** + por qué es gap + **a quién le toca** (no siempre César) + intervención mínima sugerida. Son **advisory** — alertan, no vereditan; César decide si interviene y cómo.

Usan B6: `today` (por tick), `week` (rollup de gaps recurrentes → candidatos a lección).

---

## B5 · Telemetría ROI (mínima, sin infra)

`today` agrega al final de `today-{fecha}.md` un bloque de 3 números, actualizado por los comandos:

```markdown
## Telemetría
- absorbidas_hoy: N        # menciones que el buffer encoló sin interrumpir
- borradores: usados_tal_cual=N · editados=N · rehechos=N   # lo marca César al publicar
- gate: pass=N · fail_real=N · fail_falso=N                 # ¿el gate atrapó algo real?
- fp_clasificador: N                                        # items que César marcó "no necesitaba mi acción" (calibra el criterio 🔴)
- alertas_flujo: emitidas=N · accionadas=N                  # ¿las alertas B6 valen su ruido?
```

Esto decide la adopción con datos (no con la frustración del peor día) y calibra el GAUGE/gate.

---

## Escalera de enforcement — estado HONESTO

| Guardrail | Nivel objetivo | Estado |
|---|---|---|
| Never-post | 4 hook | ✅ **ACTIVO** (`linear-write-guard.sh` + settings) |
| Estado `In Review` antes de review formal | 4 hook | ✅ **ACTIVO** (`linear-write-guard.sh` v2, probado 11/06 — 6 casos; verificación en vivo solo si se agrega `LINEAR_API_KEY`, hoy corre por snapshot/fail-closed) |
| @juli + @ignacio mencionados en la SOLICITUD de review | 2 | prosa: P2 del pre-gate (ex-criterio 9; el evaluador re-lee el comentario de la pedida; el hook lo recuerda en el prompt) |
| Citas `file:línea` reales | 3 script | ✅ **ACTIVO** (`verify-citations.sh`) |
| Dedup memoria | 3 | ⚠️ parcial: upsert `topic_key` es mecánico; el search previo es convención |
| ¿Gate corrió? + schema | 2 | ⚠️ prosa estructurada (sub-agente + formato por criterio); sin schema duro |
| Orden migración / CI glob | 3 | ⚠️ data-rules en registry de pr-review; las ejecuta el modelo |
| Advisory ≠ regla / no reabrir | 2 | prosa + evaluador independiente (es juicio; fail-closed) |

**Regla de honestidad:** un nivel solo se declara ACTIVO cuando el artefacto (hook/script) existe y se probó — no por intención.

---

## Registry de domain rules (cómo escala lo particular)

Los checks particulares de un codebase NO van al núcleo — van al **registry de `pr-review`** (`~/.claude/skills/pr-review/knowledge/detection-rules/`, cargado por trigger; hoy es R&R-only, coherente con el applicability gate). `/linear-learn` escribe reglas nuevas ahí (DATA, no código). El núcleo no crece; el registry sí, selectivamente.
