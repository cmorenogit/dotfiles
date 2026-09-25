#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-isolate.sh — Aislamiento de worktrees Beat para MI flujo personal (worktrunk).
#
# NO es el script del equipo: ese vive en apprecio-pulse/scripts/worktree-ensure-
# isolation.sh, lo usa todo el equipo vía el CLAUDE.md del repo, y NO se toca.
# Esta es mi versión personal y autónoma, con lo que validamos:
#   - sed portable GNU/BSD (sed_inplace) — el del repo usa `sed -i ''` (rompe en GNU)
#   - config.toml sin tablas de puerto duplicadas
#   - slot determinista por NOMBRE del worktree (estable en post-start)
#   - pairing back-driven: parchea el .env del worktree-par de la app
#   - expone puertos a `wt config state vars` (alimenta [list] url de worktrunk)
#   - genera un CLAUDE.local.md rico (repo/rama/pair/puertos + cómo crear otro wt)
#
# Modos:
#   (default)     aísla el worktree (slot, config.toml, .env) + escribe CLAUDE.local.md
#   --check       solo reporta si el worktree está aislado
#   --doc-only    solo (re)genera el CLAUDE.local.md leyendo el slot ya asignado
#   --release-config  suelta config.toml (no-skip-worktree + contenido de HEAD) ANTES de
#                     merge/rebase: sin esto git choca con el skip-worktree si upstream lo cambió
#   --refresh-config  regenera config.toml desde HEAD con el slot ya asignado, DESPUÉS del
#                     merge/rebase (idempotente)
#
# config.toml: se genera desde `git show HEAD:supabase/config.toml` sustituyendo SOLO
# project_id y puertos. Antes era "header de puertos + [functions.*] del working tree de la
# BASE": perdía [api].schemas (gw) y [auth], y dependía de una base que puede estar sucia
# (incidente 24-sep-2026: 3 worktrees rearmados a mano distinto; PLA-29 perdió [auth]).
#
# Se dispara desde ~/.config/worktrunk/config.toml → [projects."…apprecio-pulse"]
# (post-start) y desde el hook post-switch (refresh-rr → --doc-only). Opera sobre
# el worktree donde corre (cwd); no depende de su propia ubicación.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

MAX_SLOTS=20
BASE_PROJECT_REF="miqfhuhcwrniqtxmidjb"

usage() {
  cat <<USAGE
Usage: $0 [--check | --doc-only | --release-config | --refresh-config]

  (sin args)        Aísla el worktree actual (puertos+project_id por slot) y escribe CLAUDE.local.md.
  --check           Solo verifica si el worktree está aislado.
  --doc-only        Solo regenera el CLAUDE.local.md (no reasigna ni reescribe config).
  --release-config  Antes de merge/rebase: config.toml vuelve a HEAD y sale de skip-worktree.
  --refresh-config  Después de merge/rebase: regenera config.toml desde HEAD con el slot actual.

Debe correrse desde dentro de un worktree Beat (no desde el repo principal).
USAGE
  exit 1
}

MODE="apply"
case "${1:-}" in
  --help) usage ;;
  --check) MODE="check" ;;
  --doc-only) MODE="doc" ;;
  --release-config) MODE="release" ;;
  --refresh-config) MODE="refresh" ;;
  "") ;;
  *) echo "ERROR: opción desconocida: $1"; usage ;;
esac

WT_DIR="$(pwd)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -z "$GIT_COMMON_DIR" ] || [ "$GIT_COMMON_DIR" = ".git" ]; then
  echo "ERROR: No estás dentro de un git worktree."
  exit 1
fi
MAIN_REPO="$(cd "$GIT_COMMON_DIR/.." && pwd)"
if [ "$WT_DIR" = "$MAIN_REPO" ]; then
  echo "ERROR: Estás en el repo principal, no en un worktree. Nada que aislar."
  exit 1
fi

SLOT_FILE="$WT_DIR/.worktree-slot"
CONFIG_FILE="$WT_DIR/supabase/config.toml"

# ── Identidad del worktree y su pair ─────────────────────────────────────────
# wt nombra los worktrees <base>.<branch|sanitize>; el pair de la otra app comparte
# el mismo sufijo. Se deriva del NOMBRE del directorio (no de `git branch`, que en
# post-start puede no resolver aún).
WT_NAME="$(basename "$WT_DIR")"
MAIN_NAME="$(basename "$MAIN_REPO")"
SUFFIX="${WT_NAME#${MAIN_NAME}.}"
PARENT="$(dirname "$MAIN_REPO")"

if [ "$MAIN_NAME" = "app-rr-cesar" ]; then
  ROLE="app"
  ROLE_LABEL="app-rr-cesar (app colaborador)"
  PAIR_DIR="$PARENT/back-pulse-cesar.${SUFFIX}"
  PAIR_LABEL="back-pulse-cesar (backoffice / bo)"
  BACK_WT="$PAIR_DIR"
else
  ROLE="back"
  ROLE_LABEL="back-pulse-cesar (backoffice / bo)"
  PAIR_DIR="$PARENT/app-rr-cesar.${SUFFIX}"
  PAIR_LABEL="app-rr-cesar (app colaborador)"
  BACK_WT="$WT_DIR"
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

# In-place sed portable GNU/BSD (evita `sed -i ''`, que GNU lee como script vacío).
sed_inplace() {
  local expr="$1" file="$2" tmp="${2}.wt-tmp.$$"
  sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
}

patch_kv() {  # key value file — set-or-append portable
  if grep -q "^$1=" "$3" 2>/dev/null; then
    sed_inplace "s|^$1=.*|$1=$2|" "$3"
  else
    echo "$1=$2" >> "$3"
  fi
}

# config.toml aislado = el de HEAD de ESTA rama con project_id y puertos del slot.
# Solo toca claves de puerto de las secciones de puertos; todo lo demás ([api].schemas,
# [auth], [functions.*], …) queda tal cual está en la rama. Secciones de puertos que la
# rama no declare se agregan al final para no caer en los puertos del base (:54321…).
write_isolated_config() {
  local src tmp="$CONFIG_FILE.wt-tmp.$$"
  src="$(git -C "$WT_DIR" show HEAD:supabase/config.toml 2>/dev/null || true)"
  if [ -z "$src" ]; then
    echo "ERROR: HEAD no tiene supabase/config.toml — no puedo generar el config aislado."
    return 1
  fi
  printf '%s\n' "$src" | awk \
    -v pid="$PROJECT_ID" -v api="$API_PORT" -v db="$DB_PORT" -v shadow="$SHADOW_PORT" \
    -v studio="$STUDIO_PORT" -v inbucket="$INBUCKET_PORT" -v analytics="$ANALYTICS_PORT" \
    -v pooler="$POOLER_PORT" '
    BEGIN {
      keys["api"] = "port = " api
      keys["db"] = "port = " db "\nshadow_port = " shadow
      keys["studio"] = "port = " studio
      keys["inbucket"] = "port = " inbucket
      keys["analytics"] = "port = " analytics
      keys["db.pooler"] = "port = " pooler
      order = "api db studio inbucket analytics db.pooler"
      sec = ""; pid_done = 0
    }
    /^\[[^]]+\]/ {
      sec = $0; gsub(/^\[|\].*$/, "", sec)
      print
      if (sec in keys) { print keys[sec]; seen[sec] = 1 }
      next
    }
    sec == "" && /^project_id[ \t]*=/ { print "project_id = \"" pid "\""; pid_done = 1; next }
    (sec in keys) && /^(port|shadow_port)[ \t]*=/ { next }
    { print }
    END {
      if (!pid_done) print "project_id = \"" pid "\""
      n = split(order, o, " ")
      for (i = 1; i <= n; i++) if (!(o[i] in seen)) printf "\n[%s]\n%s\n", o[i], keys[o[i]]
    }' > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  # El config.toml aislado es LOCAL al slot: no debe ensuciar git ni commitearse.
  # skip-worktree hace que git ignore estos cambios sin destrackear el archivo →
  # evita el "M supabase/config.toml" que bloquea wt remove, confunde a beat-unpair
  # y se filtra a commits (contaminando PRs con el project_id/puertos del slot).
  git -C "$WT_DIR" update-index --skip-worktree supabase/config.toml 2>/dev/null || true
}

# Helpers del worktree en .beat/ (ignorado vía info/exclude). q.sh: psql del slot sin psql en el
# host (sesiones: `psql: command not found`, `$PSQL` sin word-splitting en zsh, columnas adivinadas).
write_beat_helpers() {
  local dir="$1" pid="$2"
  mkdir -p "$dir/.beat"
  local exclude; exclude="$(git -C "$dir" rev-parse --git-common-dir)/info/exclude"
  case "$exclude" in /*) ;; *) exclude="$dir/$exclude" ;; esac
  grep -qxF ".beat/" "$exclude" 2>/dev/null || echo ".beat/" >> "$exclude"
  cat > "$dir/.beat/q.sh" <<QEOF
# Generado por beat-isolate.sh — psql contra el Supabase de ESTE slot ($pid). Uso:
#   source .beat/q.sh ; Q "select count(*) from profiles" ; cols challenges ; psqlw -c '\\dt'
BEAT_DB_CONTAINER="supabase_db_${pid}"
psqlw() { docker exec -i "\$BEAT_DB_CONTAINER" psql -U postgres -d postgres "\$@"; }
Q()     { psqlw -At -F \$'\\t' -c "\$1"; }
cols()  { psqlw -c "\\d \$1"; }
QEOF
}

# Engram: fija el proyecto de memoria de Beat en la sesión de Claude de este worktree.
# Sin esto engram lo deduce del remoto de git ("apprecio-pulse" en el back, "ryr-39255" en la app)
# y la memoria de Beat quedó partida en 4 proyectos (203 resúmenes de sesión fuera de
# "recognition-and-rewards", verificado 25-sep-2026). El MCP hereda el `env` de los settings
# del proyecto (probado: project_source = process_override).
write_engram_env() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  mkdir -p "$dir/.claude"
  if ! git -C "$dir" check-ignore -q .claude/settings.local.json 2>/dev/null; then
    local ex; ex="$(git -C "$dir" rev-parse --git-common-dir)/info/exclude"
    case "$ex" in /*) ;; *) ex="$dir/$ex" ;; esac
    grep -qxF ".claude/settings.local.json" "$ex" 2>/dev/null || echo ".claude/settings.local.json" >> "$ex"
  fi
  python3 - "$dir/.claude/settings.local.json" <<'PYENV'
import json, os, sys
p = sys.argv[1]
d = {}
if os.path.exists(p):
    try:
        d = json.load(open(p))
    except Exception:
        sys.exit(0)  # JSON inválido: no lo pisamos
d.setdefault("env", {})["ENGRAM_PROJECT"] = "recognition-and-rewards"
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
open(p, "a").write("\n")
PYENV
}

# Setea las variables de puerto globales a partir de un slot.
compute_ports() {
  local slot="$1"
  API_PORT=$((54321 + slot * 100))
  DB_PORT=$((54322 + slot * 100))
  STUDIO_PORT=$((54323 + slot * 100))
  INBUCKET_PORT=$((54324 + slot * 100))
  ANALYTICS_PORT=$((54327 + slot * 100))
  SHADOW_PORT=$((54320 + slot * 100))
  POOLER_PORT=$((54329 + slot * 100))
  BACK_VITE=$((8080 + slot * 100))
  APP_VITE=$((8081 + slot * 100))
  PROJECT_ID="${BASE_PROJECT_REF}-wt${slot}"
}

# True si OTRO worktree ya ocupa el slot.
slot_in_use_by_other() {
  local slot="$1" wt
  for wt in $(git worktree list --porcelain | grep "^worktree " | sed 's/^worktree //'); do
    if [ -f "$wt/.worktree-slot" ] && [ "$(cat "$wt/.worktree-slot" | tr -d '[:space:]')" = "$slot" ] && [ "$wt" != "$WT_DIR" ]; then
      return 0
    fi
  done
  return 1
}

# Slot determinista por nombre de worktree, con fallback circular anti-colisión.
pick_slot() {
  local key preferred slot i
  key="$(basename "$WT_DIR")"
  preferred=$(( $(printf '%s' "$key" | cksum | cut -d' ' -f1) % MAX_SLOTS + 1 ))
  for i in $(seq 0 $((MAX_SLOTS - 1))); do
    slot=$(( (preferred - 1 + i) % MAX_SLOTS + 1 ))
    if ! slot_in_use_by_other "$slot"; then echo "$slot"; return; fi
  done
  echo ""
}

# Escribe el CLAUDE.local.md de un worktree. Args: target_dir role_label branch pair_label pair_dir
# Usa las variables de puerto globales (compute_ports) ya seteadas.
write_claude_local() {
  local target="$1" role_label="$2" branch="$3" pair_label="$4" pair_dir="$5"
  [ -d "$target" ] || return 0
  local pair_line
  if [ -d "$pair_dir" ]; then pair_line="- Path: $pair_dir"
  else pair_line="- (pair aún no creado) — se crea solo al hacer \`wt switch --create $branch\` desde el back."; fi
  # ID del issue derivado de la rama (ryr-286 / pla-29 / RYR_300) → puntero a su bitácora.
  local issue
  issue="$(printf '%s' "$branch" | grep -oiE '(ryr|pla|app)[-_]?[0-9]+' | head -1 | tr '[:lower:]_' '[:upper:]-' | sed -E 's/^([A-Z]+)-?([0-9]+)$/\1-\2/' || true)"
  local bitacora_line="- Bitácora: la rama no trae ID de issue — si el trabajo es de un issue, ubicá su bitácora en \`~/Code/_vault/_work/apprecio/projects/rr/issues/<ID>/00-bitacora.md\`."
  [ -n "$issue" ] && bitacora_line="- Issue: **$issue** · bitácora: \`~/Code/_vault/_work/apprecio/projects/rr/issues/$issue/00-bitacora.md\` — si existe, LEELA ANTES de todo (foto + decisiones vigentes)."

  # Flujo: detalle completo solo en el backoffice (scripts, gate, PR y preview viven en el back);
  # la app recibe un puntero (el flujo es back-driven, no se duplica). Heredoc con comillas: literal.
  local flujo_qa_block=""
  case "$role_label" in
    *backoffice*) flujo_qa_block="$(cat <<'FASE'
**Fase 1 — Desarrollo (ADLC)**
1. `/adlc-start` ANTES de tocar código: spec en `docs/specs/*.md` (scope IN/OUT/DEFER, subPRs, decisiones de producto en tabla). Sin OK de César del plan, no se codea.
2. **No PR sin spec**: el spec existe Y el body del PR lo cita (`Spec: docs/specs/...md`) ANTES de abrirlo; si no, el gate de CI queda rojo PERMANENTE ("Missing spec file path"). `## Ownership` en prosa: `Build: César Moreno`.
3. Build de cada subPR (lo orquesta `/implementar <ID>`): **sub-spec por subPR** `docs/specs/AAAA-MM-DD-<feature>-pr-<N>.md` con `## Master spec` (la maestra guarda Flujo y Compuerta; el gate evalúa contra la sub-spec) → **Build Plan** de 5 líneas en el body del PR ANTES de codear (Guard 6) → `/adlc-build-loop <sub-spec> --trunk <trunk>` (13 pasos; el 12 = `/pr-review`, no existe `../pr-review-skills`). En el paso 4 (`/adlc-qa-cases`) barré además `~/Code/_vault/_work/apprecio/_shared/qa-dimensiones.md`. Tests nuevos se siembran: rojos contra la base, verdes con el fix (commiteá antes de `git checkout <base> -- <archivos>`).
4. **SubPRs = ramas DENTRO de esta sesión y este worktree** (el del trunk, creado con `wt switch -c`): de a uno, en secuencia. `git switch <trunk> && git pull --ff-only` → `git switch -c <trunk>-pr<N>` (en back y, si aplica, en la app con `git -C <pair>`). Todo commiteado antes de cambiar de rama (el guard lo exige). Implementadores en paralelo NO: comparten árbol.
5. **Merge subPR → trunk lo valida ADLC**: si el subPR toca UI, QA manual de César con `## Manual QA focus` (de `/adlc-qa-cases`) ANTES del review externo (Stage 2 §5c) → `/pr-review` READY TO MERGE → body con `## Decisiones autónomas esta sesión` → `/adlc-pre-merge <PR>` sin bloqueantes → CI verde (el hook lo exige) → **César confirma la evidencia runtime** (un resultado observable que él pueda reproducir; curl o tests no cuentan) → `gh pr merge <N> -R ivaldovinos-app/apprecio-pulse --merge` (NUNCA `--squash`; trunk → main lo mergea Hakeem). Después: `git switch <trunk> && git pull --ff-only` en back y app.
6. Gate local IGUAL a CI, con todo commiteado: `bash ~/.config/worktrunk/scripts/beat-gate.sh --body <archivo>` (antes del PR) o `--pr <N>`.

**Fase 2 — Preparar para QA** (desde este worktree del back; en orden, nada se salta)
1. **Sincronizar**: `git fetch && git merge origin/main` en el trunk (y en el trunk de la app). Para no chocar con `supabase/config.toml`: `bash ~/.config/worktrunk/scripts/beat-isolate.sh --release-config` → merge → `--refresh-config`. Merge commit, nunca squash.
2. **Migraciones en orden**: `bash ~/.config/worktrunk/scripts/beat-migration-order.sh` → sin ✗. Una migración ≤ max(origin/main) la saltea `db push` en prod (RYR-296, PLA-29): re-estampar al promover.
3. **Build + tests locales** (salida literal, no "pasó"):
   - `npm run build` en back Y app (tsc/vitest no ven errores de build; `pr-check` solo corre en PRs a main).
   - unit: `bash scripts/run-unit-tests.sh`
   - service: `bash ~/.config/worktrunk/scripts/beat-service-tests.sh` (stack RECIÉN arrancado y con candado: el stack de test :44321 es global; si otra sesión lo tiene, avisa quién — `--wait` para esperar. Nunca `docker stop`, nunca reset en caliente).
   - e2e del módulo: `USE_DEV_SUPABASE=1 bash scripts/run-e2e.sh -- tests/e2e/<carpeta>/` (sin la variable no corre contra este stack).
   - fallos preexistentes: A/B contra la base del trunk (revertí y re-corré) antes de declararlos ajenos.
4. **Escalera QA LOCAL** (pre-flight): `/adlc-qa-ladder` peldaños 0-6, 8, 9; el 7 contra el stack local queda PARCIAL. Peldaño 8 = `/pr-review`. Es read-only: lo que encuentre → subPR de fix.
5. **Preview** (solo existe para PRs con base `main`, `preview-deploy.yml:6`):
   - Vehículo: PR trunk → main (back) + PR homónimo en `ryr-39255`. El body lleva `## Promotion PR` (gate en modo `multi`) + `Spec:` de la maestra + lista de subPRs (el preview empareja la app por NOMBRE de rama). Para validar un subPR antes del trunk: rama `preview/<slug>` = trunk + fix + `merge origin/main`, PR "SOLO PREVIEW" a main, y se cierra al rescatar la evidencia.
   - **Los 3 labels, SIEMPRE y juntos**: `deploy:staging` (corre backend-tests: sin él se omiten errores, RYR-287) + `deploy:preview` + `skip:e2e` (por capacidad, temporal). Usá `bash ~/.config/worktrunk/scripts/beat-promote.sh` (crea el PR con los 3 en un solo comando; ponerlos de a uno cancela runs). Nunca quitar `deploy:preview` de un PR abierto: el workflow DESTRUYE el preview.
   - Esperar sin `sleep`: Monitor con `until ! gh pr checks <N> -R ivaldovinos-app/apprecio-pulse 2>&1 | grep -qE 'pending|in_progress'; do sleep 30; done` (un solo vigilante por PR).
   - Verificar que sirve TU código: el log no dice "App branch ... not found — using 'main'"; `python3 ~/.claude/skills/preview-db/preview_db.py list` (tag → revisión) = HEAD. Si falla gcloud → César corre `! gcloud auth login`. Tras un redeploy, re-login (el JWT viejo se invalida).
   - Smoke: flag activo, usuario demo válido, UI usable (chrome-devtools; capturas en `.beat/evidence/`), resultado confirmado en BD con `preview_db.py <PR> get/count`. Escribir en el preview (`--confirm`) lo corre César con `!`.
6. **Escalera QA sobre el PREVIEW** (Convergence Mode: revalida 7, 4 y 3): `/adlc-qa-ladder <PR> --issue <ID>`. Veredicto contra el ISSUE. **Sin esta escalera en PASS/PASS CONDICIONADO no se redacta la solicitud.** C0/C1 → subPR de fix → redeploy → escalera otra vez.
7. **Evidencia final al PR**: capturas y resultados como comentarios del PR (imagen subida a GitHub) o gist secreto sin datos de tenant; nunca commitear binarios (`.beat/evidence/` es solo el borrador local).
8. **Antes del borrador**: HEAD del último `/pr-review` == HEAD actual (si no, revisar el delta); re-leer el hilo de Linear desde el último comentario visto; cada cifra/afirmación del borrador con su comando o fuente.
9. **Solicitud** (borrador vía `/voz`; César publica; 1 OK = 1 publicación): un solo comentario; el issue pasa a **In Review**. Destinatario por PRECEDENTE (bitácora `publicar-*.md` / hilo del issue o del padre). URLs del comentario "Preview Environment" del PR. Sin rutas locales, bitácora ni engram en el texto; cc al final; nunca "merge" ni "si quieres lo hago yo".
   - **Primera solicitud** → según el TIPO de issue: **feature/mejora de producto** (superficie de usuario, trunk con varios subPRs) → **Plantilla A-F** (CR @hakeem + QA @nicole); **issue chico / fix de motor, DB o plataforma** → **Plantilla A-W** (QA worker de @ignacio, cc @hakeem). Si el issue o el padre ya fijó otro reparto, gana el precedente.
   - **Iteración tras un veredicto** → REPLY (`parentId`) al comentario del veredicto con las condiciones cerradas y la evidencia nueva; no un comentario nuevo de primer nivel.
   - **Cierre** (aprobaciones completas) → Plantilla D.
10. **Post-deploy** (cuando Hakeem avisa que llegó a producción): `/implementar <ID> --observe` → Compuerta → `/adlc-qa-post-deploy-validation` → Stage 4 Observe (Sentry + Mixpanel vs baseline) → Stage 5 Decide (decisión con dueño y plazo, knowledge, `decision-log/`) → cierre de bitácora.

---
**Plantilla A-F — Feature de producto: Code Review + QA (primera solicitud)**

### **Solicitudes formales**

Con el estándar técnico validado de mi parte (escalera QA sobre el preview + `/pr-review` en READY TO MERGE):

@hakeem — Solicito formalmente code review de tus agentes en los PRs:
* PR#XXX (BACKOFFICE): [ivaldovinos-app/apprecio-pulse#XXX](link)
* PR#YY (APP): [ivaldovinos-app/ryr-39255#YY](link)

@nicole — Solicito formalmente el primer ciclo de QA. Ambientes:
* **Backoffice:** https://pr-XXX.apprecio-pulse-preview.pages.dev
* **App:** https://pr-XXX.ryr-app-preview.pages.dev

---
**Plantilla A-W — Issue chico o fix de motor/DB/plataforma: QA worker (primera solicitud)**

@ignacio — El issue pasa a **In Review** con los PRs listos para tu QA worker. Te dejo los ambientes y el mapa de lo que cambió, para que la corrida apunte donde hay riesgo real:
* PR#XXX (BACKOFFICE): [ivaldovinos-app/apprecio-pulse#XXX](link)
* **Backoffice:** https://pr-XXX.apprecio-pulse-preview.pages.dev

Mapa de riesgo: <invariantes · dónde apunta el riesgo · qué es preexistente y no del PR>.

cc @hakeem

---
**Plantilla D — Listo para merge (cierre)**

@hakeem — Con las aprobaciones completas:
* Code review: READY TO MERGE · QA: aprobado
* Trunks al día con main · CI en verde · migraciones en orden (`beat-migration-order.sh` sin ✗)

PRs: Backoffice #XXX · App #YY. **Orden de deploy:** backend (#XXX) ANTES que frontend (#YY). La condición es tuya como dueño del deploy.
FASE
)" ;;
    *) flujo_qa_block="$(cat <<'FASE'
**Flujo**: es **back-driven** (spec, gate, tests, preview, escalera QA y solicitud se manejan desde el worktree del back; ver su `CLAUDE.local.md`). En la app NO dupliques ese flujo, salvo:
- El PR de la app también lleva su spec en `docs/specs/` y el body lo cita (el gate de la app lo exige).
- `npm run build` + tests de la app antes de pedir QA.
- La rama de la app se llama IGUAL que la del back (el preview las empareja por nombre).
FASE
)" ;;
  esac
  cat > "$target/CLAUDE.local.md" <<EOF
# Beat Workspace — worktree aislado (auto-generado por beat-isolate.sh — NO commitear)

## ⚠️ LO PRIMERO (en orden)
Este repo opera bajo ADLC (ver \`CLAUDE.md\`; ese archivo y \`stages/**\` son del equipo y se sincronizan desde ADLC core: NO se editan).
$bitacora_line
- \`mem_search\` (project "recognition-and-rewards") con el ID y el módulo antes de actuar.

$flujo_qa_block

## Reglas de ejecución (errores medidos en 212 sesiones, sep-2026)
- **Git**: la base es solo lectura. Leer otra rama = \`git show <ref>:<path>\` / \`git grep <p> <ref>\`. Stash solo explícito (\`push -m … -- <paths>\`, \`apply/drop <ref>\`). Si el guard bloquea algo, NO lo esquives: reportalo.
- **Pair**: \`git -C <pair>\` o rutas absolutas; nunca \`cd\` al pair en un Bash compartido.
- **gh**: siempre \`-R ivaldovinos-app/apprecio-pulse\` o \`-R ivaldovinos-app/ryr-39255\`.
- **BD local**: no hay psql en el host → \`source <worktree-del-back>/.beat/q.sh\`; \`cols <tabla>\` ANTES de escribir un SELECT/INSERT; \`Q "<sql>"\`.
- **Esperas**: \`run_in_background\` o Monitor; nunca \`sleep\` ni \`--watch\` en primer plano.
- **Evidencia/capturas/bodies de PR**: en \`.beat/\` del worktree (ignorado por git), no en \`/tmp\`.
- **Afirmaciones**: cada número o "todos/ninguno" sale de un comando citado (repo · HEAD · N). Lo que no mediste, no lo afirmes.
- **Hallazgos preexistentes**: tabla para Ignacio antes del primer commit; un issue nuevo solo si César lo pide.

## Estás acá
- Repo: $role_label
- Rama: $branch
- Path: $target

## Pair (el OTRO repo de esta misma feature)
- Repo: $pair_label
$pair_line
- Para tocar el pair, usá EXACTAMENTE ese path. NUNCA edites en la carpeta BASE
  del repo (\`back-pulse-cesar\` / \`app-rr-cesar\` sin sufijo): puede estar en otra rama.

## Ambiente aislado (slot ${SLOT})
- Supabase  → API http://127.0.0.1:${API_PORT} · Studio http://127.0.0.1:${STUDIO_PORT} · DB :${DB_PORT}
- project_id: ${PROJECT_ID}
- Vite      → backoffice :${BACK_VITE} · app :${APP_VITE}
- Levantar (desde el back \`back-pulse-cesar.${SUFFIX}\`): \`supabase start\` y \`npm run dev\`
- \`supabase/config.toml\` es LOCAL al slot (skip-worktree, generado desde HEAD). Para merge/rebase
  NO lo rearmes a mano: \`bash ~/.config/worktrunk/scripts/beat-isolate.sh --release-config\` →
  merge/rebase → \`bash ~/.config/worktrunk/scripts/beat-isolate.sh --refresh-config\`.

## Crear OTRO worktree (MI flujo = worktrunk, back-driven)
- Para un issue: \`wt issue <rama> <ID>\` (worktree + par de la app + sesión de Claude en Supacode con /implementar). Otra sesión en un worktree existente: \`wt issue-open <rama> <ID>\`. Sin sesión: \`wt switch --create <rama>\` desde \`back-pulse-cesar\`.
- NO uses \`scripts/worktree-setup.sh\` (ese es el flujo del EQUIPO que documenta el CLAUDE.md del repo; yo uso worktrunk).
- Crealo SIEMPRE desde el back (el back es dueño del stack Supabase y provisiona ambos).

## Anti-confusión (importante)
- Si \`git branch --show-current\` ≠ \`$branch\`, avisá antes de seguir.
- No edites/borres carpetas hermanas (otros \`*.{sufijo}\` o las bases): cada una es otra rama/slot.

## Engram — política Beat
- SIEMPRE \`project: "recognition-and-rewards"\` en mem_save / mem_search / mem_context.
- Contenido PE personal (carrera, evaluaciones, 1:1): \`scope: "personal"\`, NO el project.

## Formato de títulos de issues (Linear)
Al crear un issue en Linear, usar el formato estandarizado (lote Crecer/Entrenamientos RYR-163..167):
\`[Pn] <Área> / <Módulo> · <síntoma>\`
- \`[Pn]\`: severidad entre corchetes (P1/P2/P3). Si no hay severidad definida, **omitir** el prefijo (no inventar peso).
- \`<Área> / <Módulo>\`: p.ej. \`Crecer / Entrenamientos\`, \`Transversal / Correos\`.
- \` · \` (interpunct, no guion) como separador antes del síntoma.
- El texto describe el **síntoma** (qué falla), no la solución; conciso.
- Ejemplo: \`[P1] Crecer / Entrenamientos · No se visualizan los documentos de evidencia del avance de misiones\`.
EOF
}

# Rama legible (con fallback al sufijo si git aún no resuelve, p.ej. en post-start).
branch_of() {
  local d="$1" b
  b="$(git -C "$d" branch --show-current 2>/dev/null || echo "")"
  [ -n "$b" ] && echo "$b" || echo "$SUFFIX"
}

# ── --check ──────────────────────────────────────────────────────────────────
if [ "$MODE" = "check" ]; then
  if [ -f "$SLOT_FILE" ]; then
    echo "OK: worktree aislado (slot $(cat "$SLOT_FILE" | tr -d '[:space:]'))."
    exit 0
  fi
  echo "NOT ISOLATED: este worktree no tiene aislamiento."
  exit 1
fi

# ── --doc-only ───────────────────────────────────────────────────────────────
# Regenera el CLAUDE.local.md del worktree actual leyendo el slot ya asignado.
# El slot vive en el worktree del BACK; si estoy en el app, lo leo de su back-pair.
if [ "$MODE" = "doc" ]; then
  SLOT=""
  [ -f "$BACK_WT/.worktree-slot" ] && SLOT="$(cat "$BACK_WT/.worktree-slot" | tr -d '[:space:]')"
  if [ -z "$SLOT" ]; then
    echo "(worktree no aislado todavía — corré beat-isolate sin --doc-only desde el back)"
    exit 0
  fi
  compute_ports "$SLOT"
  [ "$BACK_WT" = "$WT_DIR" ] && write_beat_helpers "$WT_DIR" "$PROJECT_ID"
  write_engram_env "$WT_DIR"
  write_claude_local "$WT_DIR" "$ROLE_LABEL" "$(branch_of "$WT_DIR")" "$PAIR_LABEL" "$PAIR_DIR"
  exit 0
fi

# ── --release-config / --refresh-config ─────────────────────────────────────
# Ciclo de merge/rebase sin rearmar config.toml a mano:
#   beat-isolate.sh --release-config  →  git merge/rebase …  →  beat-isolate.sh --refresh-config
if [ "$MODE" = "release" ] || [ "$MODE" = "refresh" ]; then
  if [ "$BACK_WT" != "$WT_DIR" ]; then
    echo "ERROR: config.toml vive en el back — corré esto desde $BACK_WT"
    exit 1
  fi
  if [ "$MODE" = "release" ]; then
    git -C "$WT_DIR" update-index --no-skip-worktree supabase/config.toml
    git -C "$WT_DIR" checkout HEAD -- supabase/config.toml
    echo "config.toml liberado (contenido de HEAD, fuera de skip-worktree). Hacé el merge/rebase y"
    echo "después: bash ~/.config/worktrunk/scripts/beat-isolate.sh --refresh-config"
    exit 0
  fi
  SLOT=""
  [ -f "$SLOT_FILE" ] && SLOT="$(tr -d '[:space:]' < "$SLOT_FILE")"
  if [ -z "$SLOT" ]; then
    echo "ERROR: worktree sin slot — corré beat-isolate sin argumentos primero."
    exit 1
  fi
  compute_ports "$SLOT"
  write_isolated_config
  write_beat_helpers "$WT_DIR" "$PROJECT_ID"
  echo "config.toml regenerado desde HEAD para el slot $SLOT ($PROJECT_ID, API :$API_PORT)."
  exit 0
fi

# ── apply (default): aísla este worktree ─────────────────────────────────────
SLOT=$(pick_slot)
if [ -z "$SLOT" ]; then
  echo "ERROR: todos los $MAX_SLOTS slots están en uso. Eliminá un worktree primero."
  exit 1
fi
compute_ports "$SLOT"

echo "=== Worktree Isolation ==="
echo "  Directory:  $WT_DIR"
echo "  Slot:       $SLOT"
echo "  Project ID: $PROJECT_ID"
echo "  Supabase:   API=$API_PORT DB=$DB_PORT Studio=$STUDIO_PORT"
echo "  Vite:       back=$BACK_VITE app=$APP_VITE"
echo ""

echo "$SLOT" > "$SLOT_FILE"

# config.toml aislado: el de HEAD de esta rama con project_id + puertos del slot (+ skip-worktree).
write_isolated_config
write_beat_helpers "$WT_DIR" "$PROJECT_ID"

echo "$PROJECT_ID" > "$WT_DIR/.supabase-project-id.local"


# Vite lee .env.local con MAS prioridad que .env: un .env.local copiado del base
# por wt copy-ignored pisa el aislamiento del slot (bug 2026-07-13: la app del
# slot 3 pegaba al :54321 del base). Neutralizarlo, no parchearlo — dos archivos
# con la misma config es drift asegurado.
neutralize_env_local() {
  if [ -f "$1/.env.local" ]; then
    mv "$1/.env.local" "$1/.env.local.pre-isolate.bak"
    echo "  (avisa: $1/.env.local movido a .env.local.pre-isolate.bak — pisaba el .env del slot)"
  fi
}

# .env del back worktree
if [ ! -f "$WT_DIR/.env" ] && [ -f "$MAIN_REPO/.env" ]; then
  cp "$MAIN_REPO/.env" "$WT_DIR/.env"
fi
if [ -f "$WT_DIR/.env" ]; then
  patch_kv "VITE_SUPABASE_URL" "http://127.0.0.1:${API_PORT}" "$WT_DIR/.env"
  patch_kv "VITE_PORT" "${BACK_VITE}" "$WT_DIR/.env"
  grep -q "^SUPABASE_PUBLIC_URL=" "$WT_DIR/.env" 2>/dev/null \
    && patch_kv "SUPABASE_PUBLIC_URL" "http://127.0.0.1:${API_PORT}" "$WT_DIR/.env" || true
fi
neutralize_env_local "$WT_DIR"

# supabase/functions/.env (API_URL para rewrite de storage URLs)
FUNCTIONS_ENV="$WT_DIR/supabase/functions/.env"
if [ ! -f "$FUNCTIONS_ENV" ] && [ -f "$MAIN_REPO/supabase/functions/.env" ]; then
  mkdir -p "$WT_DIR/supabase/functions"
  cp "$MAIN_REPO/supabase/functions/.env" "$FUNCTIONS_ENV"
fi
[ -f "$FUNCTIONS_ENV" ] || { mkdir -p "$WT_DIR/supabase/functions"; touch "$FUNCTIONS_ENV"; }
patch_kv "API_URL" "http://127.0.0.1:${API_PORT}" "$FUNCTIONS_ENV"

# Pairing back-driven: parchear el .env del worktree-par de la app.
if [ "$ROLE" = "back" ] && [ "$SUFFIX" != "$WT_NAME" ] && [ -d "$PAIR_DIR" ]; then
  APP_ENV="$PAIR_DIR/.env"
  if [ ! -f "$APP_ENV" ]; then
    if [ -f "$PARENT/app-rr-cesar/.env" ]; then cp "$PARENT/app-rr-cesar/.env" "$APP_ENV"
    elif [ -f "$PAIR_DIR/.env.example" ]; then cp "$PAIR_DIR/.env.example" "$APP_ENV"
    else touch "$APP_ENV"; fi
  fi
  patch_kv "VITE_SUPABASE_MODE" "local" "$APP_ENV"
  patch_kv "VITE_SUPABASE_URL" "http://127.0.0.1:${API_PORT}" "$APP_ENV"
  patch_kv "VITE_SUPABASE_LOCAL_URL" "http://127.0.0.1:${API_PORT}" "$APP_ENV"
  patch_kv "VITE_PORT" "${APP_VITE}" "$APP_ENV"
  neutralize_env_local "$PAIR_DIR"
  echo "  App pair:   $PAIR_DIR (.env → API :$API_PORT, Vite :$APP_VITE)"
else
  echo "  App pair:   (no encontrado para sufijo '$SUFFIX' — se parchea al crearlo desde el back)"
fi

# Exponer puertos a worktrunk (alimenta [list] url y aliases).
if command -v wt >/dev/null 2>&1; then
  wt config state vars set \
    project_id="$PROJECT_ID" api_port="$API_PORT" studio_port="$STUDIO_PORT" vite_port="$BACK_VITE" \
    >/dev/null 2>&1 || true
fi

# CLAUDE.local.md rico en este worktree y en el pair (si existe).
write_engram_env "$WT_DIR"
write_claude_local "$WT_DIR" "$ROLE_LABEL" "$(branch_of "$WT_DIR")" "$PAIR_LABEL" "$PAIR_DIR"
if [ -d "$PAIR_DIR" ]; then
  write_engram_env "$PAIR_DIR"
  write_claude_local "$PAIR_DIR" "$PAIR_LABEL" "$(branch_of "$PAIR_DIR")" "$ROLE_LABEL" "$WT_DIR"
fi

echo ""
echo "=== Isolation applied ==="
echo "  supabase start   # API=$API_PORT DB=$DB_PORT"
echo "  npm run dev      # Vite back :$BACK_VITE"
