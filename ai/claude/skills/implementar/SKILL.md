---
name: implementar
description: Implementa un issue de Linear de Beat con ADLC de punta a punta DENTRO del worktree de su rama (ya creado con `wt issue <rama> <ID>`) — spec maestra + sub-spec por subPR, build con /adlc-build-loop, evidencia confirmada por César, promoción con preview (3 labels) y escalera QA, borrador de la solicitud; y tras el deploy, `--observe` (Stages 4-5). Uso — /implementar <ID> | /implementar <ID> --observe. Nunca crea ramas ni worktrees.
disable-model-invocation: true
argument-hint: <ID de Linear> [--observe]
---

# implementar — un issue, una rama, una sesión, ADLC completo

`$ARGUMENTS` = `<ID>` (p. ej. `RYR-301`), opcionalmente seguido de `--observe` (fase post-deploy, §7). La mecánica (comandos, recetas, plantillas) vive en el `CLAUDE.local.md` de este worktree y ADLC en `CLAUDE.md` + `stages/` + `.claude/commands/adlc-*`: este skill los **orquesta**, no los reemplaza ni los reescribe.

## 0. Guarda (antes de todo)

1. Esta sesión corre en un **worktree** (no en la base): `git rev-parse --git-dir` ≠ `--git-common-dir`. Si estás en `back-pulse-cesar` o `app-rr-cesar` sin sufijo → **detenete** y decile a César: `wt issue <rama> <ID>`.
2. La rama corresponde al issue (el ID está en el nombre, o César lo confirma). Si no → detenete y preguntá.
3. **Nunca** creás ramas de otros issues ni worktrees. Los subPRs de ESTE trunk sí se crean acá (§4).
4. Con `--observe` → saltá directo a §7.

## Autorizaciones y frenos (valen toda la sesión)

- AUTORIZO merge subPR → trunk (`--merge`, nunca squash) SOLO con TODO esto: `/adlc-pre-merge` sin bloqueantes · CI verde (el hook lo exige) · unit + service + build locales verdes · `/pr-review` READY TO MERGE sobre el HEAD actual · sin C0/C1 abiertos · sin decisiones de producto pendientes · **César confirmó la evidencia runtime** (§4.6) · si el subPR toca UI, **César hizo el QA manual** (§4.4).
- NUNCA: merge a main, publicar en Linear/GitHub, crear issues, escribir en la BD del preview, tocar `CLAUDE.md`, `stages/**`, `scripts/adlc/*` ni `.github/workflows/*`. Si un hook bloquea algo, NO lo esquives: reportalo.
- Bitácora: cosechas sin confirmación, salvo si podan un blocker vivo o una decisión abierta.
- Pausas previstas (esperás a César): OK del plan (§3) · QA manual de subPRs con UI (§4.4) · confirmación de evidencia runtime antes de cada merge (§4.6) · decisión de producto no delegada · merge fuera de lo autorizado · escritura sobre el preview · la escalera recorta el alcance a menos de la mitad.
- Toda afirmación sale de un comando corrido ahora (repo · HEAD · N).

## 1. Contexto (ADLC Hard Rule 4)

- Linear: `get_issue` + **todos** los comentarios (`list_comments`), el padre, relacionados y PRs adjuntos.
- La foto de la bitácora llega al inicio de la sesión (hook). Leé la bitácora completa si existe; si el issue cruza sesiones y no tiene, proponé crearla.
- `mem_search` con el ID y el módulo. Knowledge: `global-core.md`, `global-pulse.md`, `infrastructure.md`, `ryr.md` + `decision-log/` del módulo (decisiones aceptadas sin implementar y las últimas 5 retros).
- Prerrequisitos: `gcloud auth print-access-token` (si falla, pedile a César `! gcloud auth login`: sin eso no hay verificación del preview).

## 2. Clasificación (decide el resto)

| Pregunta | Opciones | Efecto |
|---|---|---|
| ¿Tipo? | feature/mejora de producto · issue chico o fix de motor/DB/plataforma | Solicitud con Plantilla **A-F** (CR @hakeem + QA @nicole) o **A-W** (QA worker de @ignacio, cc @hakeem). Si el issue o el padre fijó otro reparto, gana el precedente |
| ¿Forma? | trunk con subPRs · PR único | Con trunk: la rama de esta sesión ES el trunk y los subPRs salen de ella. PR único: §4 corre una vez sobre esta rama con la spec maestra (sin sub-spec) |

## 3. Plan — Stage 1 (interactivo, termina con el OK de César)

1. `/adlc-start` con el contenido del issue → **spec maestra** en `docs/specs/YYYY-MM-DD-<feature>.md` según `stages/1-spec` (6 campos; si es Feature también Alcance IN ≥2 / NOT IN ≥1, Decisiones de producto, Compuerta a producción ≥2 condiciones verificables, Flujo con identificadores greppables y `[CRITICAL]`). La maestra guarda el Flujo y la Compuerta completos.
2. En el mismo plan: **lista de subPRs** (uno por concern, orden y dependencias) con la **matriz criterio → subPR → test**. Hallazgos preexistentes: tabla para Ignacio, no subPRs extra.
3. `/grill` sobre el plan.
4. Con el OK: `/bitacora` (crear o adoptar) + push del trunk en back y app. Devolvele a César esta línea para que la mande como mensaje propio:
   `/goal <ID>: preview del PR trunk→main sirviendo el HEAD (beat-promote --check sin ✗), escalera QA sobre el preview sin C0/C1 del PR, y borrador de la solicitud guardado en el vault — o detenido esperando una decisión o confirmación explícita de César.`

## 4. SubPRs — Stages 2 y 3 (dentro de esta sesión y este worktree, de a uno)

Por cada subPR N, en secuencia:

1. **Rama**: `git switch <trunk> && git pull --ff-only` → `git switch -c <trunk>-pr<N>` (back y, si aplica, app con `git -C <pair>`).
2. **Sub-spec** (Stage 2 §Multi-PR): `docs/specs/YYYY-MM-DD-<feature>-pr-<N>.md` con los 6 campos de lo que ESTE subPR entrega (tracking/runtime propios; `defer`/`n/a` es legítimo en migraciones o andamiaje) y `## Master spec: docs/specs/…-<feature>.md`. El gate evalúa el PR contra ESTA sub-spec, no contra la maestra.
3. **Build** — subagente (general-purpose, foreground) con brief autocontenido: sub-spec, spec maestra, alcance EXACTO, decisiones cerradas, paths/puertos, reglas del `CLAUDE.local.md`, y la orden:
   "Primero el **Build Plan** (5 líneas: Base · i18n · Tracking · Risk · Verify) en el body del PR (Guard 6): sin Build Plan no hay código. Después `/adlc-build-loop <sub-spec> --trunk <trunk>` pasos 1-11: `/adlc-qa-change-risk-analysis`, `/adlc-qa-regression-impact-analysis`, `/adlc-qa-distributed-flow-analysis`, `/adlc-qa-cases`, `/adlc-unit-integration-test-gap-analysis`, `/adlc-api-contract-testing`, `/adlc-playwright-auto-test-generation`, `/adlc-qa-test-data-management` (o 'no aplica' con razón), suite completa, `/adlc-review` interno (máx. 2) y el lazo `/adlc-qa-pre-deploy-evidence-gate`. La Verificación Runtime del PR lleva por cada afirmación: tipo, link, transcripción literal del valor y qué prueba. No preguntes, no mergees, no publiques. Decisión de producto → BLOCKED con la tabla. Informe completo a `.beat/<ID>-pr<N>-build.md`; mensaje final ≤25 líneas: PR#, HEAD, tests del XML, gate, resultado de cada paso, hallazgos abiertos."
4. **QA manual de César — solo si el subPR toca UI** (formularios, wizards, diálogos, guards por rol, CRUD; Stage 2 §5c): primero agotá tu evidencia (Playwright real, fixtures, llamadas adversariales); después armá el `## Manual QA focus` con `/adlc-qa-cases` (qué flujos, qué roles, qué casos borde, por cada path de UI del diff) y **esperá** su resultado. Hallazgos → fix → VERIFY otra vez → volvé acá. Queda en el body: `## Manual QA: PASS` o `## Manual QA: N findings applied, re-verified`.
5. **Review y pre-merge** — hilo principal: verificá lo reportado (`beat-gate.sh --pr N`, XML de CI, que el Build Plan esté en el body). `/pr-review <PR>` (paso 12; y el de la app). Fixes en lote por subagente → re-review. Con CI verde, el body lleva `## Decisiones autónomas esta sesión` (decisión · alternativa descartada · razón · reversibilidad; Stage 2 §5). `/adlc-pre-merge <PR>` (paso 13) sin bloqueantes.
6. **Confirmación de la evidencia runtime** (Stage 2 §VERIFY + `/adlc-pre-merge` §E): mostrale a César la Verificación Runtime del PR — al menos un resultado observable que él pueda reproducir (pantalla con el valor transcrito, fila en BD tras la acción, URL que responde) — y **esperá su OK**. Un log de curl o la salida de tests no cuentan.
7. **Merge** `--merge` → `git switch <trunk> && git pull --ff-only` → cosecha de bitácora (subPR, PR#, SHA) → `mem_save` si hubo algo no obvio.

## 5. Promoción y QA sobre el preview (Fase 2 del `CLAUDE.local.md`, en orden)

1. Sync con main (`--release-config` → merge → `--refresh-config`).
2. Build + tests locales (unit, service, e2e del módulo). **Escalera QA LOCAL** `/adlc-qa-ladder` (pre-vuelo: peldaños 0-6, 8, 9; el 7 queda PARCIAL por falta de preview; el 8 es `/pr-review`).
3. Body del PR de promoción: `## Promotion PR` (el gate entra en modo `multi`: los checks por spec ya se validaron en cada subPR) + `Spec:` de la maestra + lista de subPRs mergeados. `beat-promote.sh --title … --body … [--app-body …] --dry-run` → sin ✗ → sin `--dry-run` (crea el PR con los 3 labels juntos).
4. Esperar con Monitor → `beat-promote.sh --check <PR>` sin ✗ → smoke (flag, usuario demo, UI visible, resultado en BD con `preview_db.py`).
5. **Escalera QA sobre el PREVIEW** `/adlc-qa-ladder <PR> --issue <ID>` (Convergence Mode: revalida 7, 4 y 3; el peldaño 7 corre el flujo real contra el preview y lo verifica en su BD). Veredicto contra el ISSUE. **Bloqueante** para el borrador; C0/C1 → subPR de fix (§4) → redeploy → escalera otra vez.
6. **Evidencia final al PR** (Stage 2 §Evidence storage): capturas y resultados como **comentarios del PR** (imagen subida a GitHub) o gist secreto sin datos de tenant; nunca commitear binarios. `.beat/evidence/` es solo el borrador local.
7. HEAD revisado == HEAD actual → borrador con `/voz` y la plantilla de §2, guardado en `~/Code/_vault/_work/apprecio/projects/rr/issues/<ID>/publicar-YYYY-MM-DD.md` con frontmatter `status: borrador`. NO lo publicás. Cuando César confirme que lo publicó, cambiá a `status: publicado`.

## 6. Carga de la sesión

Si la sesión se compacta o pesa: cosechá la bitácora con el próximo paso y después `/handoff` (foco: "continuar <ID> desde <paso>"). En Supacode, un hook abre la pestaña de continuación en este mismo worktree. La sesión nueva corre `/implementar <ID>` otra vez y retoma desde la bitácora; el `/goal` se vuelve a fijar.

## 7. Post-deploy — `/implementar <ID> --observe` (Stages 4 y 5)

César lo corre cuando Hakeem avisa que el trunk llegó a producción.

1. **Compuerta** (Stage 2 §7): verificá cada condición de `## Compuerta a producción` de la spec maestra. Alguna sin cumplir → reportá el estado y **no** actives Stage 4.
2. **Validación post-deploy** (build-loop paso 14): `/adlc-qa-post-deploy-validation` con el contrato post-deploy que emitió el paso 11 — read-only sobre producción.
3. **Stage 4 · Observe**: `scripts/adlc/fetch-sentry.sh` + `scripts/adlc/fetch-mixpanel.sh` contra la métrica y el baseline de la spec (sin baseline: últimos 7 días pre-deploy). Alertas inmediatas: errores >2× el baseline o un tipo de error nuevo. No se hace informe: se arma el paquete de datos.
4. **Stage 5 · Decide**: decisión con acción, dueño y plazo (≤48 h si es de sistema) según `stages/5-decide/template.md`; regla nueva → knowledge (`global-pulse.md` o `ryr.md`; `global-core.md` NO se edita: se propone a ADLC core); export a `decision-log/YYYY-MM-DD-rr-<feature>.json` por PR. "Iterar" → la entrada de la próxima spec.
5. Cierre: `/bitacora` (cerrar) y, si hubo aprendizaje de proceso, `/adlc-retro`.

## Entregable

Fases 3-5: tabla de subPRs (sub-spec · PR · SHA · QA manual · evidencia confirmada · estado), veredicto de la escalera local vs preview, URLs del preview, ruta del borrador y huecos declarados. Fase 7: estado de la Compuerta, paquete de datos y la decisión exportada. Cierre: `mem_session_summary(content=…)`.
