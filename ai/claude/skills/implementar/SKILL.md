---
name: implementar
description: Implementa un issue de Linear de Beat de punta a punta DENTRO del worktree de su rama (ya creado con wt switch -c / beat-spawn.sh) — contexto, plan con /grill, subPRs al trunk validados por ADLC, promoción con preview (3 labels) y escalera QA, hasta el borrador de la solicitud de QA + Code Review. Uso — /implementar <ID>. Nunca crea ramas ni worktrees.
disable-model-invocation: true
argument-hint: <ID de Linear, p. ej. RYR-301>
---

# implementar — un issue, una rama, una sesión

`$ARGUMENTS` = ID del issue (p. ej. `RYR-301`). La mecánica (comandos, recetas, plantillas) vive en el `CLAUDE.local.md` de este worktree: este skill no la repite.

## 0. Guarda (antes de todo)

1. Esta sesión corre en un **worktree** (no en la base): `git rev-parse --git-dir` ≠ `--git-common-dir`. Si estás en `back-pulse-cesar` o `app-rr-cesar` sin sufijo → **detenete** y decile a César: `bash ~/.config/worktrunk/scripts/beat-spawn.sh <rama> <ID>`.
2. La rama corresponde al issue (el ID está en el nombre, o César lo confirma). Si no → detenete y preguntá.
3. **Nunca** creás ramas de otros issues ni worktrees. Los subPRs de ESTE trunk sí se crean acá (paso 4).

## Autorizaciones y frenos (valen toda la sesión)

- AUTORIZO merge subPR → trunk (`--merge`, nunca squash) SOLO con: `/adlc-pre-merge` sin bloqueantes, CI verde (el hook lo exige), unit + service + build locales verdes, `/pr-review` READY TO MERGE sobre el HEAD actual, sin C0/C1 abiertos y sin decisiones de producto pendientes.
- NUNCA: merge a main, publicar en Linear/GitHub, crear issues, escribir en la BD del preview, tocar `CLAUDE.md`, `stages/**`, `scripts/adlc/*` ni `.github/workflows/*`. Si un hook bloquea algo, NO lo esquives: reportalo.
- Bitácora: cosechas sin confirmación, salvo si podan un blocker vivo o una decisión abierta.
- Te detenés y preguntás SOLO ante: decisión de producto no delegada, merge fuera de lo autorizado, escritura sobre el preview, o si la escalera recorta el alcance a menos de la mitad.
- Toda afirmación sale de un comando corrido ahora (repo · HEAD · N).

## 1. Contexto

- Linear: `get_issue` + **todos** los comentarios (`list_comments`), el padre, relacionados y PRs adjuntos.
- La foto de la bitácora ya llega al inicio de la sesión (hook). Leé la bitácora completa si existe; si el issue cruza sesiones y no tiene, proponé crearla.
- `mem_search` con el ID y el módulo. Knowledge: `global-core.md`, `global-pulse.md`, `infrastructure.md`, `ryr.md` + `decision-log/` del módulo.
- Prerrequisitos: `gcloud auth print-access-token` (si falla, pedile a César `! gcloud auth login`: sin eso no hay verificación del preview).

## 2. Clasificación (decide el resto)

| Pregunta | Opciones | Efecto |
|---|---|---|
| ¿Tipo? | feature/mejora de producto · issue chico o fix de motor/DB/plataforma | Solicitud con Plantilla **A-F** (CR @hakeem + QA @nicole) o **A-W** (QA worker de @ignacio, cc @hakeem). Si el issue o el padre fijó otro reparto, gana el precedente |
| ¿Forma? | trunk con subPRs · PR único | Con trunk: la rama de esta sesión ES el trunk y los subPRs salen de ella |

## 3. Plan (interactivo, termina con el OK de César)

1. `/adlc-start` con el contenido del issue → spec (scope IN/OUT/DEFER medido, subPRs uno por concern con orden y dependencias, decisiones de producto en tabla, Compuerta, matriz criterio → subPR → test). Hallazgos preexistentes: tabla para Ignacio, no subPRs extra.
2. `/grill` sobre el plan.
3. Con el OK: `/bitacora` (crear o adoptar) + push del trunk en back y app. Devolvele a César esta línea para que la mande como mensaje propio:
   `/goal <ID>: preview del PR trunk→main sirviendo el HEAD (beat-promote --check sin ✗), escalera QA sobre el preview sin C0/C1 del PR, y borrador de la solicitud guardado en el vault — o detenido esperando una decisión explícita de César.`

## 4. SubPRs (dentro de esta sesión y este worktree, de a uno)

Por cada subPR, en secuencia (Fase 1 del `CLAUDE.local.md`):
1. `git switch <trunk> && git pull --ff-only` → `git switch -c <trunk>-pr<N>` (back y, si aplica, app con `git -C <pair>`).
2. Subagente (general-purpose, foreground) con brief autocontenido: spec, alcance EXACTO del subPR, decisiones cerradas, paths/puertos, reglas del `CLAUDE.local.md`, y la orden: "`/adlc-build-loop <spec> --trunk <trunk>` pasos 1-11 (el 12 y 13 los hace el hilo principal). No preguntes, no mergees, no publiques. Decisión de producto → BLOCKED con la tabla. Informe completo a `.beat/<ID>-pr<N>-build.md`; mensaje final ≤25 líneas: PR#, HEAD, tests del XML, gate, hallazgos abiertos."
3. Hilo principal: verificá lo reportado (`beat-gate.sh --pr N`, XML de CI). `/pr-review <PR>` (y el de la app). Fixes por subagente → re-review (máx. 3 vueltas, después escalá).
4. `/adlc-pre-merge <PR>` sin bloqueantes → merge `--merge` → `git switch <trunk> && git pull --ff-only` → cosecha de bitácora → `mem_save` si hubo algo no obvio.

## 5. Promoción y QA (Fase 2 del `CLAUDE.local.md`, en orden)

1. Sync con main (`--release-config` → merge → `--refresh-config`).
2. Build + tests locales; escalera QA LOCAL (peldaño 7 PARCIAL).
3. `beat-promote.sh --title … --body … [--app-body …] --dry-run` → sin ✗ → sin `--dry-run` (crea el PR con los 3 labels juntos).
4. Esperar con Monitor → `beat-promote.sh --check <PR>` sin ✗ → smoke (flag, usuario demo, UI, BD con `preview_db.py`).
5. `/adlc-qa-ladder <PR> --issue <ID>` sobre el preview (Convergence Mode). **Bloqueante** para el borrador.
6. HEAD revisado == HEAD actual → borrador con `/voz` y la plantilla del paso 2, guardado en `~/Code/_vault/_work/apprecio/projects/rr/issues/<ID>/publicar-YYYY-MM-DD.md` con frontmatter `status: borrador`. NO lo publicás. Cuando César confirme que lo publicó, cambiá a `status: publicado` (el hook de inicio lista los borradores pendientes).

## 6. Carga de la sesión

Si la sesión se compacta o pesa: cosechá la bitácora con el próximo paso y después `/handoff` (foco: "continuar <ID> desde <paso>"). En Supacode, un hook abre la pestaña de continuación en este mismo worktree. La sesión nueva corre `/implementar <ID>` otra vez y retoma desde la bitácora; el `/goal` se vuelve a fijar.

## Entregable

Tabla de subPRs (PR · SHA · estado), veredicto de la escalera local vs preview, URLs del preview, ruta del borrador y huecos declarados. Cierre: `mem_session_summary(content=…)`.
