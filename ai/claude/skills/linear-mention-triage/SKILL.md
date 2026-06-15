---
name: linear-mention-triage
description: >
  [DEPRECATED as standalone — prefer /linear-today, which runs this skill as its internal B1 detection
  engine (see ~/.claude/skills/_shared/linear-contract.md).] Triage César's pending Linear @mentions
  across his teams and draft in-lane replies. Invoke directly ONLY on explicit /linear-mention-triage.
  Triggers: "qué me menciona", "revisar mis menciones", "menciones pendientes", "triage Linear",
  "qué tengo pendiente en Linear", "ponerme al día con Linear", "/linear-mention-triage".
---

# Linear Mention Triage

Una sola pregunta: **¿qué tengo pendiente en Linear?** Encuentra las @menciones REALES de César sin
responder, las ordena por confianza, y redacta un borrador para las claras. Una lista corta y confiable
de un vistazo — no un documento que César tenga que volver a escanear.

Global skill: works from any session/cwd. Reads Linear + (on demand) code.
**NEVER posts to Linear** — drafts only; César posts.

## Reglas rectoras (gobiernan todo lo de abajo)

> **1. Leer la realidad, siempre — sin caché de skip.** Cada corrida lee fresco: para TODO issue en ventana, descripción AND comentarios en orden real. Leer es barato; omitir un ask es el peor fallo. No hay fingerprint que autorice saltarse una lectura. El `scan-index` solo recuerda **qué respondió César** (para marcar "viene de antes"); no es fuente de verdad ni veredicto.
>
> **2. Una mención real solo se descarta por EVIDENCIA, nunca por tono.** Ante un `@cmoreno`, un `<user id="6a1e659a-…">`, o un `Cesar/César` real sin respuesta posterior de César → es PENDIENTE. Dos únicas pruebas de descarte: (a) César comentó DESPUÉS de la mención, o (b) el match fue un falso positivo del patrón (confirmado al re-leer). "Es narrativo / atributivo / FYI" NO son pruebas — la duda baja a **🟡 decidí vos**, visible, nunca a silencio.
>
> **3. Cita-o-no-existe.** Todo item lleva **quote textual exacto + comment_id/source**. Si el quote no aparece byte-a-byte en su fuente → es alucinación, se descarta. Toda detección barre **descripción AND comentarios**.
>
> **4. Verificá contra lo ya decidido y lo ya aprendido — no reabras lo cerrado.** Antes de afirmar algo o pedir un cambio (`MUST/SHOULD FIX`, veredicto), cruzá el contenido contra (a) las **decisiones ya cerradas en el hilo** —en especial las que **el propio César ya validó**— y (b) la **memoria persistida**: `_shared` (siempre) + engram (best-effort). Un hallazgo cierto en abstracto que el equipo ya evaluó y cerró **NO es un FIX**; reabrirlo —o contradecir algo que César ya aprobó, o repetir un error ya corregido— es el **peor falso positivo** (erosiona su criterio ante el equipo). La verificación produce HECHOS; el veredicto los filtra por el contexto de decisión. Info genuinamente nueva → **pregunta/insumo citando la decisión previa**, nunca condición. (Operacionalizado en el gate §3.5 Criterio 8 + `--recheck`.)

## Identity & config (hardcoded)

- **User:** displayName `cmoreno`, id `6a1e659a-ca3d-417f-b460-b62307d9354d`, email `cmoreno@dcanje.com`.
- **Teams to scan:** Beat (`RYR`, id `ddeaea1c-b29b-45b4-82b2-6cd261c47aa5`), Platform (`PLA`), App Rewards (`APP`), Product Planning (`PRO`, id `280b014b-1731-4bd9-996a-8b2e7d8370db`). **PRO incluido a propósito:** es donde Nicole/Ignacio hacen discovery/shaping y etiquetan a César como gate técnico ANTES de que el trabajo aterrice en Beat (su lane más temprano). El ruido de PP (issues `Signal` auto-creados por Sentry/Mixpanel) se descarta solo: el clasificador exige mención literal a César. Causa de inclusión: FN real 15/06 — `@cmoreno` en PRO-42 no detectado por estar PRO fuera del scan (rescatado de rebote vía el epic RYR-131 en Beat).
- **Watch target (`--watch`):** Ignacio = id `1f03f08d-db10-4bf2-8999-499b7842f50c` (handle `@ignacio`). Otros: resolver con `list_users`/`get_user`.
- **Digest output:** `~/Code/_vault/_work/apprecio/linear/today/{YYYY-MM-DD}-{am|pm}.md` (`am` si hora local < 13:00, si no `pm`). Una corrida = un archivo (no sobrescribir).
- **scan-index:** `~/Code/_vault/_work/apprecio/linear/scan-index.md` (vault-only, formato §4).
- **Output language:** español (resúmenes + drafts). El razonamiento interno puede ser en inglés.

Al inicio, verificar identidad una vez: `get_user("me")` → confirmar que el id es `6a1e659a-…`. Si difiere, re-resolver antes de escanear.

## Tools (may be deferred — load via ToolSearch first if needed)

- Identity: `get_user` (Linear native).
- Enumeración: pm-agents `search_linear_issues(team_key, limit=200)` — tabla lean (identifier/title/state/priority/assignee/labels, SIN descripciones). **Caveat:** filtra por estado, NO por `updatedAt` — para respetar `--since`, una llamada `list_issues(team, updatedAt="-P{N}D")` parseada SOLO por campos lean (id/identifier/title/updatedAt) da el set en ventana.
- **Lector primario de detección:** `list_comments(issueId, orderBy="createdAt")` consumido **newest-first**, paginado hasta `hasNextPage=false`. `read_linear_issue`/`get_issue` SOLO para la descripción — **nunca** como única fuente del "último comentario" (trunca threads largos en silencio → causó RYR-6 FP + RYR-83 FN).

Schemas: `select:mcp__linear__get_user,mcp__linear__list_issues,mcp__linear__get_issue,mcp__linear__list_comments`, `select:mcp__pm-agents-remote__search_linear_issues`.

## Inputs

- `--since <Nd>` — ventana (default `7d` → `updatedAt="-P7D"`).
- `--teams <KEYS>` — coma-lista (default `RYR,PLA,APP,PRO`).
- `--verify <ISSUE-ID>` — corre **Pass 2** (verificación profunda de código) para un issue en vez del triage completo.
- `--watch <person>` — **Watch mode**: oportunidades proactivas OPCIONALES sobre las menciones de otra persona (default `ignacio`).
- `--recheck <ISSUE-ID>` — **re-validación de seguridad (post-borrador)**: corre SOLO el **Criterio 8** del gate §3.5 (decisión-cerrada + memoria) sobre un borrador YA escrito o un comentario YA redactado para ese issue. Cruza el contenido contra (a) las decisiones cerradas del hilo vivo, (b) `_shared`, (c) engram (best-effort). Úsalo cuando ya hay un borrador/comentario y querés confirmar que no reabre una decisión ni contradice una corrección previa antes de publicar. **Input del borrador:** el texto presente en la conversación, o el archivo `~/Code/_vault/_work/apprecio/projects/<proyecto>/issues/<ISSUE-ID>/triage.md` si existe (proyecto por prefijo: RYR→rr; declarar cuál se usó). Devuelve **PASS** o **FAIL con la cita de la decisión que contradice**.

---

## Pass 1 — Triage (invocación default)

### 1. Detectar menciones (scan acotado, lectura fresca)

Linear no tiene endpoint "mentions-of-me", así que detectar es un scan acotado. **No hay paso de caché que decida qué leer — se lee todo lo que está en ventana.**

1. Por cada team: enumerar con `search_linear_issues` (tabla lean) + resolver la ventana `--since` con un `list_issues(updatedAt="-P{N}D")` parseado por campos lean. Nunca volcar descripciones completas (≈70k chars para ~50 issues → revienta el budget).
2. **Barrido dual obligatorio — descripción AND comentarios, sin excepción.** Una mención puede estar en cualquiera; un scan que leyó solo comentarios es INVÁLIDO. Descripción vía `get_issue` (campo description); comentarios vía `list_comments(orderBy="createdAt")` newest-first. Detectar con **3 patrones** (cualquiera cuenta), registrando por hit `source + comment_id + quote verbatim`:
   - **Tag en descripción:** `<user id="6a1e659a-ca3d-417f-b460-b62307d9354d">` — match por UUID. Es @mención de primera clase, NO name-drop (se omitió en RYR-82).
   - **@-mención en comentario:** `@cmoreno`, word-boundary (no `@cmoreno2`).
   - **Display-name en prosa:** `C[eé]sar` word-boundary en desc o comentarios sin handle/UUID (se omitió en RYR-87/88). Dedupe contra los hits de handle/UUID.
   - **Guardas:** paginar `list_comments` hasta `hasNextPage=false` (nunca decidir desde un read truncado — RYR-6/RYR-83). Antes de clasificar, registrar `sources_read: [description, comments]`; si falta una → re-leer.
3. **Filtro pending (por timestamp).** Sobre la lista COMPLETA de comentarios newest-first: el issue es *pendiente* si la mención/tag más reciente **dirigida a César** es posterior al último comentario que el propio César escribió (`author.id = 6a1e659a-…`). Un "César comentó alguna vez" NO resuelve un ask posterior; una aprobación vieja no cierra una iteración nueva (esto escondió RYR-83). Si tras leer todo no podés garantizar que viste el comentario más reciente → **PENDIENTE**.
4. **Verificación de evidencia (ambas direcciones).** Para threads grandes (80+ comentarios), correr el barrido paginado en un **sub-agente** que devuelve SOLO `{comentario más reciente, último de César, cada mención-a-César con timestamp + quote verbatim}` — paginando a `hasNextPage=false`. Por cada mención reportada, re-leer la fuente citada y confirmar que el quote aparece **byte-a-byte** y que el token (`@cmoreno`/UUID/`C[eé]sar`) está literalmente dentro. Si no aparece verbatim → alucinación → descartar (RYR-87). Re-chequear también menciones que el sub-agente pudo OMITIR (tags en descripción).

### 2. Clasificar por confianza (no por bucket)

Cada mención pendiente cae en UN nivel. La duda baja un nivel (hacia visible), nunca a descarte silencioso:

- **🔴 Necesita tu respuesta** — requiere las TRES condiciones (feedback César 11/06, cura del FP RYR-111): **(a)** CTA/pregunta dirigida a César dentro de su lane (validación de estándar técnico — el code review formal es de Ignacio, regla `8763ae44` 11/06); **(b)** sigue ABIERTA tras leer el flujo POSTERIOR a la mención (nadie la cerró: ni el autor auto-respondiéndose, ni otro resolviéndola, ni la conversación avanzando sin César); **(c)** alguien espera la respuesta de César para avanzar. **Incluye iteraciones de validación técnica en su lane aunque no haya signo de pregunta** (un dev entregando iter 2 espera su sign-off → RYR-83). Un llamado de atención que el flujo ya cerró NO es 🔴 — baja a 🟡 "acuse opcional" (con advertencia del costo relacional si se repite el silencio con Ignacio). Lleva borrador.
- **🟡 Decidí vos (ambiguo)** — mención real sin respuesta posterior de César que: no tiene ask literal (handoff/iteración/atribución/tag), o que el clasificador descartaría por JUICIO en vez de evidencia, o cuyo dueño parece ser otro (Ignacio = QA/merge; Nicole = scope de producto). **Destino de toda duda.** Sin borrador — cita + por qué dudo + dueño probable si aplica.
- **Descartado (no se lista item por item)** — SOLO por evidencia: César respondió después, o match falso. Va como **una línea de conteo** al final (ej. `18 descartados — ya respondidos o match falso: RYR-6, RYR-44…`). No se cita uno por uno: ahí muere el ruido.

**Agrupar por ISSUE, no por mención (regla anti-ruido).** La unidad de visualización es el **issue**, no la mención individual. Un issue con varias menciones aparece **UNA sola vez**, en el nivel MÁS ALTO de cualquiera de sus menciones (si tiene aunque sea una 🔴 → va en 🔴; sus otras menciones 🟡 cuelgan como sub-bullets dentro de la misma tarjeta). **Todos los conteos del header son por issue** (`{N} necesitan respuesta` = N issues, no N menciones). Sin esto, un issue charlado como RYR-82 reaparece 5-6 veces y vuelve el ruido que este rediseño elimina.

### 3. Borradores (solo 🔴) — listos para publicar a la primera

El objetivo es que César **publique sin iterar**. Por cada 🔴, producir EN ESTE ORDEN:

1. **📖 De qué se trata** — el problema en lenguaje súper simple, para alguien que NO conoce el issue (2-3 frases, cero jerga). César a veces no participó del hilo; esto lo pone en contexto en 5 segundos.
2. **🎯 Qué respondés y por qué** — el racional del borrador en 1-2 frases: la decisión técnica + el encuadre de los criterios del perfil de Ignacio (¿se pasa a code review o no? ¿qué se considera, qué se omite?). Es el "por qué" para que César entienda qué está mandando. (Que NO repita lo de 📖: 📖 = el problema; 🎯 = la decisión.)
3. **Borrador** — confiado, lean, en español (ver Estilo). Tag `[inferido]` en todo claim de código no verificado (el gate §3.5 los resuelve antes de mostrar — un borrador publicable lleva CERO `[inferido]`).
4. **Veredicto (formato Ignacio)** — el borrador de un review en su lane CIERRA con el veredicto que Ignacio espera: **`APPROVE` / `APPROVE WITH CONDITIONS` / `CHANGES REQUESTED`**, y si hay hallazgos, en bloques **`MUST FIX` / `SHOULD FIX` / `CONSIDER`** con evidencia `ruta:línea`. `APPROVE WITH CONDITIONS` para cambios que no tocan lógica de negocio (sin nueva fase de QA). Para 🔴 que NO son review (feedback interpersonal, acceso, decisión de scope) no hay veredicto técnico — solo el borrador.
5. **⚠️ Advertencias** (si las hay) — ver §3.5 / Rules. Redactadas impersonales: dónde un criterio del perfil no está cubierto, o dónde el item roza el lane de Nicole/Julieth. Nunca «Ignacio diría/pediría».

**Borrador condicional → 🟡, no 🔴.** Si la respuesta depende de una condición externa sin resolver («solo si la key sigue desactualizada», «si nadie lo resolvió por interno»), el item NO es un 🔴 firme: va a **🟡 decidí vos** con la condición explícita. 🔴 es solo lo que tiene un borrador publicable sin condición previa.

### 3.5. Gate de borrador — evaluador independiente (lo que evita iterar)

**Ningún borrador 🔴 se muestra hasta pasar este gate.** Por cada borrador, lanzar un **sub-agente evaluador independiente** (distinto del que redactó). Su trabajo es **verificar el borrador contra una lista de criterios objetivos** — NO encarnar a nadie.

**Barrera dura (decisión de César — "con mucho cuidado"):** el evaluador **evalúa el borrador contra los CRITERIOS de `ignacio-review-criteria.md`** (fuente canónica de criterios de review; `ignacio-product-profile.md` es solo contexto de prioridades), **nunca "actúa como Ignacio" ni predice qué diría**. Las advertencias se redactan impersonales — **«el criterio de _outcome primero_ del perfil no está cubierto»**, NUNCA **«Ignacio pediría…»**. Modelar "qué propiedad falta" es alinear; "qué diría Ignacio" es simular — prohibido (ver Rules).

**Qué recibe el evaluador:** el borrador + su veredicto; **la fuente citada que RE-LEE él mismo** (vía `comment_id` → el comentario real, no solo la cita que le pasaron — así es independiente en la EVIDENCIA, no solo en el juicio; confirma el quote byte-a-byte); los criterios del perfil; **el hilo COMPLETO** (no solo la cita — para detectar decisiones ya cerradas, Criterio 8); y **la referencia persistida** que re-lee él mismo: `_shared` (**SIEMPRE**: `ignacio-review-criteria.md` + `linear-review-lessons.md` + `learnings-*.md` + `readiness-*.md`), y engram (`mem_search` por ISSUE-ID + tema) **best-effort** — si engram difiere del vault, **gana el vault**. Si al re-leer la fuente el claim base no aparece o cambió → FAIL inmediato (la lectura del redactor era incompleta).

**Cuándo aplica el lente de producto (criterios 1-3, 7):** SOLO si la mención es un **review/decisión técnica en el lane de César**. Para 🔴 **no-review** (feedback interpersonal, gestión, pedido de acceso/secrets) → esos criterios se marcan **N/A** y NO se corre el lente de producto. **Si la mención es de Ignacio o está dirigida a Ignacio, el lente de su perfil NO se usa en absoluto** (evaluar un mensaje a Ignacio con su propio perfil es la trampa de simulación) — solo corren los criterios 4-6.

**Chequeo de decisión cerrada + memoria (Criterio 8) — la barrera que faltó (RYR-83, 04-jun).** Antes de emitir CUALQUIER `MUST FIX`/`SHOULD FIX` o veredicto, el evaluador cruza cada hallazgo contra:
> - **Las decisiones YA tomadas en el hilo.** Si el punto de tu hallazgo ya fue planteado y **cerrado** por alguien —Ignacio lo vetó, el dev lo acordó, o —el peor caso— **el propio César ya validó un plan que tu borrador contradice**— → el hallazgo NO es válido como condición. La verificación de código produce **HECHOS**; el veredicto los filtra por el **contexto de decisión** del hilo. Un hallazgo cierto en abstracto («la migración está out-of-order») **no es un FIX** si el equipo ya lo evaluó y decidió lo contrario con conocimiento de causa.
> - **La memoria/lecciones persistidas.** `_shared` (perfil, `learnings-contratos-compartidos-y-agentes-ia.md`, `learnings-preview-environments-cicd.md`, `readiness-y-evaluacion-pr-issues.md`) **siempre**, y engram (`mem_search`) best-effort. Si el borrador repite un error ya corregido o contradice una preferencia/convención registrada → FAIL.
>
> **Regla dura:** NUNCA contradecir una decisión que César ya validó en el hilo — es el **peor falso positivo** (erosiona su criterio ante el equipo). Si hay info **genuinamente nueva** que justifique reabrir, va como **pregunta/insumo citando la decisión previa**, jamás como condición que da la decisión por no-tomada.

| # | Criterio | Aplica a | FAIL si… |
|---|---|---|---|
| 1 | **Outcome primero** | review | el problema admite un outcome/métrica de negocio y el borrador no lo nombra |
| 2 | **Estado + next step + owner** explícitos; si atascado, decisión binaria de scope | review | el próximo paso o el dueño quedan implícitos |
| 3 | **Causa raíz, no parche; no remueve defensa** (`tenant_id`/RLS) | review con fix | propone parchar el síntoma o quitar una defensa |
| 4 | **Lane** — técnico; lo de QA/scope va como INSUMO a Julieth/Nicole, no como veredicto | todos | el borrador aprueba QA, decide scope, o invade otro lane |
| 5 | **Verificación** — **CERO** claims `[inferido]` (sin excepción de "no-decisivo") | todos | queda cualquier `[inferido]` sin `[verificado: file:línea]` |
| 6 | **Estilo** — confiado, lean, sin hedging/disclaimers/auto-aclaración de lane | todos | hay relleno, dudas ("debería confirmar…") o se justifica de más |
| 7 | **Veredicto** — cierra con APPROVE/CONDITIONS/CHANGES + MUST/SHOULD/CONSIDER, evidencia `ruta:línea` | review | falta el veredicto o su evidencia |
| 8 | **No reabre decisión cerrada / respeta corrección persistida** | todos | el borrador propone (FIX o veredicto) algo que el hilo YA discutió y cerró, **o que contradice un plan que César ya validó**, o una corrección/preferencia/lección registrada en `_shared`/engram |
| 9 | **Solicitud de review bien formada** (lección RYR-111) | review | el borrador emite veredicto sobre una PEDIDA inválida: el comentario que solicitó la review formal no menciona a **@juli** (QA siguiente) y a **@ignacio** (revisión/merge), o el issue NO está en `In Review`. El evaluador re-lee el comentario de la solicitud (`comment_id`) y el estado del issue — no confía en lo que le pasaron |

**Resolución:**
- **Todos PASS / N/A** → **✅ Listo para publicar**.
- **FAIL en criterios de contenido/forma (1-4, 6-7)** → el evaluador **reescribe**, **máximo 2 vueltas**. Si tras 2 vueltas un criterio sigue sin cerrar → mostrar el borrador marcado **⚠️ {criterio} no cerró** (no loop infinito; César decide con el dato).
- **FAIL en #5 (claim sin verificar)** → **verificación LIGERA inline** SOLO si es confirmar UN hecho citado (≤2 lecturas puntuales: `grep` de un símbolo, leer la línea citada). **Si exige trazar el path entre capas (root cause real) → eso es Pass 2, NO se corre en el triage default:** el borrador se marca **⚠️ No publicable aún — falta verificar {check decisivo}** → `--verify {ISSUE-ID}`. **Un APPROVE nunca puede descansar en `[inferido]`.**
- **FAIL en #9 (solicitud de review mal formada):** **el veredicto se RETIRA** — no se publica review sobre una pedida inválida. El borrador se reescribe como **devolución de proceso** (liviana): qué le falta a la solicitud (estado `In Review` / cc a @juli / cc a @ignacio) para re-solicitarla bien. César puede ordenar override explícito.
- **FAIL en #8 (reabre decisión cerrada / choca con corrección persistida)** → **retirar el hallazgo del veredicto** y **recalcular el veredicto sin él** (un SHOULD FIX retirado puede convertir un `APPROVE WITH CONDITIONS` en `APPROVE` limpio — fue exactamente el caso RYR-83). Si el evaluador juzga que hay info **genuinamente nueva** que amerite reabrir → reescribir como **pregunta/insumo citando la decisión previa**, nunca como condición. Jamás dejar en el borrador algo que contradiga una decisión ya cerrada o que César ya validó.
- **Choque con tu juicio técnico o roce de lane** → el evaluador NO sobrescribe: agrega **⚠️ el perfil prioriza {X} y el borrador no lo cubre** / **⚠️ roza el lane de {Nicole/Julieth} — encuadrado como insumo**. César decide.

Bias del evaluador: **default a FAIL ante la duda** — preferible una reescritura interna (acotada a 2) a que César publique y tenga que corregir en Linear.

### 4. Escribir el digest + scan-index

Digest al path (am/pm, un archivo por corrida). **Sello de hora de corte en el header.** Marcar como "viene de antes" lo que ya apareció en un digest previo y sigue pendiente.

`scan-index.md` — **registro de qué respondió César, NO autorización para saltarse lecturas.** 3 columnas, vault-only, se reescribe cada corrida con lo efectivamente leído. **Si el archivo en disco tiene el formato viejo (9 columnas con `desc_hash`/`last_comment_id`/`classification`), sobrescribirlo al formato de 3 columnas en esta corrida — y nunca leer una columna `classification` heredada como veredicto (viola la Regla 1).**

```markdown
---
last_scan: 2026-06-03T13:39-05   # hora local de corte
window: 7d · teams: RYR,PLA,APP,PRO
---
| issue | respondió César (fecha) | nota |
|---|---|---|
| RYR-82 | no | 🔴 review estándar PR#538 |
| RYR-6  | 28/05 16:18 | descartado — respondido |
```

---

## Digest format

```markdown
# Pendientes Linear — {YYYY-MM-DD} ({AM|PM})
_{N} necesitan respuesta · {M} a decidir · {D} descartados · escaneado {HH:MM} {TZ} · ventana {N}d · teams {…}_
_(todos los conteos son por ISSUE, no por mención)_

## 🔴 Necesitan tu respuesta ({N} issues)

### {ISSUE-ID} — {título corto}   ✅ Listo para publicar | ⚠️ No publicable aún
- **Quién/cuándo:** {autor} · {top-level|reply} · {fecha}{ · viene de antes}
- **Cita:** `{comment_id|DESCRIPTION}` · «{cita textual EXACTA con el @cmoreno/UUID/Cesar}»
- **📖 De qué se trata:** {problema en lenguaje súper simple, sin jerga, 2-3 frases}
- **🎯 Qué respondés y por qué:** {racional: decisión técnica + encuadre de Ignacio — pasar/no pasar, qué se considera}
- **Borrador:**
  > {respuesta confiada, lean, en español}
  >
  > {si es review:} **Veredicto: APPROVE | APPROVE WITH CONDITIONS | CHANGES REQUESTED**
  > {MUST FIX / SHOULD FIX / CONSIDER con evidencia `ruta:línea`, si hay}
- **⚠️ Advertencia:** {solo si aplica — «el perfil prioriza X y el borrador no lo cubre» / «roza lane de Nicole — encuadrado como insumo»}
- {solo si NO está listo:} **⚠️ Falta verificar {check decisivo}** → `--verify {ISSUE-ID}`
- _También en este issue (decidí vos):_ `{comment_id}` «{cita}» — {qué es}   ← menciones 🟡 del MISMO issue cuelgan acá, no en su propia sección

## 🟡 Decidí vos ({M} issues) — ordenados por confianza, los más probables arriba
- **{ISSUE-ID}** — `{comment_id|DESCRIPTION}` · «{cita exacta}» — {qué es: handoff/iteración/tag} · {por qué dudo}{ · dueño probable: Ignacio/Nicole}

## Descartados ({D})
{ISSUE-ID, ISSUE-ID…} — ya respondidos por César o match falso. (Detalle en scan-index.)
```
**Caducidad:** foto a las {HH:MM}. Los asks entran durante el día — re-corré antes de decir "estás al día".

---

## Pass 2 — Verify (`--verify <ISSUE-ID>`) · opt-in, profundo

Confirmar o corregir cada claim `[inferido]` de un borrador contra el código REAL. Se invoca explícitamente; el triage default NO lo corre.

1. `read_linear_issue(<ISSUE-ID>, comment_limit=<N>)` — descripción + thread acotado.
2. **Trazar el path vivo end-to-end:** componente renderizado → hook/service → endpoint → handler backend → el campo/cómputo exacto. El bug vive donde el contrato diverge entre dos capas.
3. **Leer el código — TRES capas, en orden:**
   - **(1) Clones locales (preferido, READ-ONLY):** `~/Code/work/rr-project/` → `app-rr-cesar` (front, `ivaldovinos-app/ryr-39255`), `back-pulse-cesar` (back, `ivaldovinos-app/apprecio-pulse`). `git -C <base> fetch -q` y luego `git -C <base> grep -n '<patrón>' <ref>` lee CUALQUIER rama sin checkout. **NUNCA** `checkout`/`pull`/`merge`/`reset` ni tocar los clones `.<feature>`.
   - **(2) pm-agents `grep_repo`/`read_repo_file`** (repos `app`/`backend`/`force-manager`/`pulse`): primario para `pulse` y second-opinion del read local. `ryr-39255` NO es repo pm-agents. (No usar `glob` — es poco confiable; buscar sin él, leer por path.)
   - **(3) `gh` CLI (fallback):** solo si no hay clone local. **Nunca concluir "no puedo acceder al código".**
4. **Guardas anti-alucinación:** confirmar que el componente está renderizado (`grep` su uso — dead code es trampa clásica); seguir el campo EXACTO que la UI lee; "correcto en otro lado" ≠ "correcto en el campo consumido"; descartar una capa NO prueba otra; confirmar que la RPC/función backend es la definición MÁS NUEVA (`CREATE OR REPLACE` — grep todas, leer la última); para la COMPLETITUD de un fix, enumerar los paths hermanos (un fix que toca un constraint/campo compartido debe cubrir TODOS sus writers).
5. **Fix-calibration gate (cuando el remedio toca un feature flag).** Tres remedios mutuamente excluyentes — elegir el correcto por flag, nunca "seed them all":

   | Estado del flag | Cómo confirmar | Fix correcto |
   |---|---|---|
   | Ausente de `feature_flag_defaults` | `grep_repo(pulse,'<flag>')` halla el flag pero sin seed row | **SEED** `default_value=true` |
   | Seeded `default=true` pero off para un tenant | grep confirma el seed; síntoma tenant-scoped | **OVERRIDE** en `tenant_feature_flags` (lógica AND) — NO re-seed; revisar/limpiar el override |
   | **0 referencias en backend** | `grep_repo(pulse,'<flag>')` = 0 matches | Nunca fue flag backend → **REMOVER el gate en el frontend** |

   **Check duro antes de recomendar "seed `<flag>`":** correr `grep_repo(pulse,'<flag>')`. **0 matches → recomendación de seed PROHIBIDA** (mandaría a Soporte a perseguir un fantasma — el peor fallo de Pass 2). Nombrar el fix positivo: grep el frontend para señalar el gate exacto a borrar.
6. Subir cada claim a `[verificado: file:línea]` o corregirlo. Si no podés alcanzar el código que lo decide, decilo y da el check decisivo runtime/DB — **no publiques un root cause solo inferido.**
7. Refinar ese borrador para que sea seguro de postear (file:line exacto, sin `[inferido]`).

**Estado de publicación (dos estados, nunca intermedio):** "100% verificado — acá está el draft" O "todavía no — esto es lo que falta verificar". La verificación es del skill, no del usuario — César nunca debería preguntar "¿verificaste?".

*(Cache de análisis Pass 2 opcional: `~/Code/_vault/_work/apprecio/projects/<proyecto>/issues/<ISSUE-ID>/triage.md` (proyecto por prefijo: RYR→rr) — un archivo por issue con el root cause verificado + refs `file:línea`. Sirve para recuperar el diagnóstico; al re-correr, SIEMPRE re-leer el thread vivo + re-confirmar los `file:línea` antes de reusar. No suprime lectura.)*

---

## Watch mode (`--watch <person>`) · opcional, advisory

Oportunidades proactivas OPCIONALES sobre menciones a OTRA persona (default **Ignacio**, id `1f03f08d-…`) donde el aporte técnico de César sumaría. Opt-in; el skill nunca redacta un barge-in ni postea.

1. Resolver el id del target (Ignacio por default).
2. Scan de menciones al target (`@ignacio` + su UUID en descripción), mismo barrido dual que Pass 1.
3. Mantener SOLO los que pasan los 3 gates: **abierto** (sin respuesta que lo cierre) · **técnico y en el dominio de César** (código/arquitectura R&R, no proceso/QA/scheduling/producto) · **César aporta valor** real. En la duda, DROP — acá los falsos positivos son ruido puro.
4. Por sobreviviente: resumen plain + por qué César sumaría + ángulo SUGERIDO (no draft) con `[inferido]`. Marcar **OPCIONAL — vos decidís**.
5. Sección aparte "Oportunidades proactivas (opcional)" — NUNCA mezclada con 🔴. Preferir POCAS y de alta confianza.

---

## Rules (el valor del skill)

**Lane.** César es el *technical-standard stopper*: decide SOLO "¿el dev cumplió lo necesario para avanzar a code review?". NO aprueba QA ni merges (→ **Ignacio**), NO es dueño del scope de producto (→ **Nicole**). Los items 🟡 nombran al dueño en vez de redactar respuesta.

**Estilo (borradores).** Confiado y lean: sin disclaimers, sin auto-aclaración de lane, sin hedging ("debería confirmar…"), sin deletrear next-steps asumidos. Liderar con el veredicto, luego la evidencia precisa. Responder lo que se pregunta, nada más.

**Lente de Ignacio (central — gobierna el contenido del borrador, no solo el tono).** Todo borrador 🔴 se construye y se evalúa (gate §3.5) contra `~/Code/_vault/_work/apprecio/linear/knowledge/ignacio-review-criteria.md` (criterios canónicos de review) + `ignacio-product-profile.md` (contexto de prioridades) — las fuentes de "cómo Ignacio resuelve": cuándo se pasa a code review y cuándo no, qué se considera, qué se omite. El borrador debe: liderar con el **outcome/métrica** de negocio (no el detalle técnico); hacer explícito **estado + next step + dueño nombrado** (+ decisión binaria de scope si está atascado); **root-cause, no parche**; **nunca proponer remover una defensa** (`tenant_id`, RLS); preferir **centralizar lo cross-cutting en la RPC canónica**; `observe` antes de `enforce`; encuadrar lo técnico como **insumo** para el dueño (Julieth=calidad, Nicole=scope), no como veredicto sobre su lane. Para decisiones-a-tomar, su tabla ADLC (`#, Decisión, Opciones, Recomendación, Status`); para reviews, su formato `APPROVE/CONDITIONS/CHANGES` + `MUST/SHOULD/CONSIDER`.

> **Dos barreras duras (no negociables):**
> - **Es para ALINEAR, nunca para SIMULAR.** El skill modela "qué priorizaría/valoraría Ignacio", jamás "qué diría". Nunca poner palabras en su boca, nunca firmar como él, nunca atribuirle una opinión.
> - **Advierte, no sobrescribe (decisión de César).** El borrador es de César (criterio técnico). Donde un criterio del perfil choca con su juicio, o el item roza el lane de Nicole/Julieth, el skill agrega una línea **⚠️** impersonal («el perfil prioriza X…»), nunca «Ignacio diría/pediría…», y César decide — NO reescribe el veredicto técnico por su cuenta.

**Rigor (anti-alucinación).** Nunca afirmar que una mención/ask EXISTE sin quote verbatim + source/comment_id (RYR-87). Nunca afirmar un hecho de código desde comentarios solos — tag `[inferido]` hasta `[verificado: file:línea]`. Nunca un root cause sin trazar el path vivo end-to-end. Un veredicto confiado-pero-errado es peor que "todavía no — acá está el check decisivo".

---

## Notes / gotchas

- **3 encodings de mención:** `@cmoreno` (comentarios, word-boundary) · `<user id="UUID">` (descripción, @mención de primera clase) · `Cesar/César` en prosa (sin handle). Los tres son REALES → mínimo 🟡, nunca descarte silencioso (gaps reales en RYR-82/87/88).
- **`list_issues` trae descripciones completas** → puede pasar el límite de tokens (~70k para 50 issues). Parsear solo campos lean.
- **Lector primario = `list_comments(orderBy=createdAt)` newest-first paginado a `hasNextPage=false`** — NO `read_linear_issue` (trunca). `search_linear_issues` filtra por estado, no por `updatedAt`.
- **Sin caché de skip** (Regla 1): cada corrida lee desc + comentarios de todo issue en ventana. El `scan-index` solo recuerda "qué respondió César"; nunca decide qué saltarse.
- **Threads grandes:** nunca truncar para ahorrar tokens — paginar dentro de un sub-agente que devuelve solo `{más reciente, último de César, menciones-a-César con timestamp + quote verbatim}`.
- **Storage vault-only para ESCRITURA.** El skill no ESCRIBE a engram (para andar headless/cron); el cache de análisis y el scan-index viven en el vault. **LEER es distinto y SÍ se hace:** el gate §3.5 (Criterio 8) consulta `_shared` (siempre — es el fallback presente en cualquier run) y engram (`mem_search`, best-effort si disponible) como referencia de decisiones/correcciones previas. Leer no rompe headless porque `_shared` está siempre.
- **Anti-pattern — reabrir una decisión cerrada (RYR-83, 04-jun).** El skill publicó un `SHOULD FIX` pidiendo tocar una migración (`20260529174011`) que Ignacio había **vetado mover** y que **César mismo ya había validado mantener** en el hilo (`5cc595e1`). El hallazgo era cierto en abstracto (timestamp out-of-order) pero el thread ya lo había **resuelto** con un análisis de impacto. César borró el comentario. Causa: el veredicto no se filtró por las decisiones del hilo ni por la propia validación previa de César. **Cura: Criterio 8 del gate + `--recheck`.** Detalle en engram `apprecio/skills/linear-mention-triage-error-reabrir-decision-cerrada`.
- **Never post to Linear (default).** El skill redacta; César revisa y postea. (César puede pedir publicar puntualmente — eso es un override suyo, no cambia el default.)
