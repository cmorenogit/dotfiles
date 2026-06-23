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
Usage: $0 [--check | --doc-only]

  (sin args)   Aísla el worktree actual (puertos+project_id por slot) y escribe CLAUDE.local.md.
  --check      Solo verifica si el worktree está aislado.
  --doc-only   Solo regenera el CLAUDE.local.md (no reasigna ni reescribe config).

Debe correrse desde dentro de un worktree Beat (no desde el repo principal).
USAGE
  exit 1
}

MODE="apply"
case "${1:-}" in
  --help) usage ;;
  --check) MODE="check" ;;
  --doc-only) MODE="doc" ;;
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
  # Bloque de tests: solo en el backoffice (los scripts run-*-tests.sh viven en el back).
  local tests_block=""
  case "$role_label" in
    *backoffice*) tests_block="
## Tests (referencia rápida — corré desde este worktree del back)
- unit (todos): \`bash scripts/run-unit-tests.sh\`
- service (todos, levanta el stack Docker :44321): \`bash scripts/run-service-tests.sh\`
- e2e (SOLO el módulo; CI lo skipea → local es la única red): \`bash scripts/run-e2e.sh -- tests/e2e/<carpeta>/\`
- ⚠️ parar la BD de test al terminar (no dejar Docker consumiendo): \`bash scripts/test-supabase-stop.sh\`
- Doc completa (scope, mapeo módulo→e2e, gotchas): \`_work/apprecio/projects/rr/testing/correr-tests-locales.md\`
" ;;
  esac
  cat > "$target/CLAUDE.local.md" <<EOF
# Beat Workspace — worktree aislado (auto-generado por beat-isolate.sh — NO commitear)

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

## Crear OTRO worktree (MI flujo = worktrunk, back-driven)
- Desde \`back-pulse-cesar\`: \`wt switch --create <rama>\` → crea el par de la app y aísla solo.
- NO uses \`scripts/worktree-setup.sh\` (ese es el flujo del EQUIPO que documenta el CLAUDE.md del repo; yo uso worktrunk).
- Crealo SIEMPRE desde el back (el back es dueño del stack Supabase y provisiona ambos).

## Anti-confusión (importante)
- Si \`git branch --show-current\` ≠ \`$branch\`, avisá antes de seguir.
- No edites/borres carpetas hermanas (otros \`*.{sufijo}\` o las bases): cada una es otra rama/slot.

## Engram — política Beat
- SIEMPRE \`project: "recognition-and-rewards"\` en mem_save / mem_search / mem_context.
- Contenido PE personal (carrera, evaluaciones, 1:1): \`scope: "personal"\`, NO el project.
$tests_block
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
  write_claude_local "$WT_DIR" "$ROLE_LABEL" "$(branch_of "$WT_DIR")" "$PAIR_LABEL" "$PAIR_DIR"
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

# config.toml aislado: header de puertos del slot + SOLO las [functions.*] de main.
CONFIG_FILE="$WT_DIR/supabase/config.toml"
MAIN_CONFIG="$MAIN_REPO/supabase/config.toml"
{
  echo "project_id = \"${PROJECT_ID}\""
  echo ""
  echo "[api]";       echo "port = ${API_PORT}";       echo ""
  echo "[db]";        echo "port = ${DB_PORT}";        echo "shadow_port = ${SHADOW_PORT}"; echo ""
  echo "[studio]";    echo "port = ${STUDIO_PORT}";    echo ""
  echo "[inbucket]";  echo "port = ${INBUCKET_PORT}";  echo ""
  echo "[analytics]"; echo "port = ${ANALYTICS_PORT}"; echo ""
  echo "[db.pooler]"; echo "port = ${POOLER_PORT}";    echo ""
  # SOLO los [functions.*] de main (NO sus tablas de puerto: duplicarían [api]/[db]/...).
  sed -n '/^\[functions/,$p' "$MAIN_CONFIG"
} > "$CONFIG_FILE"

# El config.toml aislado es LOCAL al slot: no debe ensuciar git ni commitearse.
# skip-worktree hace que git ignore estos cambios sin destrackear el archivo →
# evita el "M supabase/config.toml" que bloquea wt remove, confunde a beat-unpair
# y se filtra a commits (contaminando PRs con el project_id/puertos del slot).
git -C "$WT_DIR" update-index --skip-worktree supabase/config.toml 2>/dev/null || true

echo "$PROJECT_ID" > "$WT_DIR/.supabase-project-id.local"

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
write_claude_local "$WT_DIR" "$ROLE_LABEL" "$(branch_of "$WT_DIR")" "$PAIR_LABEL" "$PAIR_DIR"
if [ -d "$PAIR_DIR" ]; then
  write_claude_local "$PAIR_DIR" "$PAIR_LABEL" "$(branch_of "$PAIR_DIR")" "$ROLE_LABEL" "$WT_DIR"
fi

echo ""
echo "=== Isolation applied ==="
echo "  supabase start   # API=$API_PORT DB=$DB_PORT"
echo "  npm run dev      # Vite back :$BACK_VITE"
