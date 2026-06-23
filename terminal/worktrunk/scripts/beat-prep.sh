#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-prep.sh — Prepara un worktree Beat tras crearlo con worktrunk (post-start).
#
# Orquesta, en el back y su par app, los pasos para dejar el worktree LISTO:
#   1. secrets      copia .env / functions/.env (wt step copy-ignored)
#   2. aislado      slot + puertos + config.toml + .env (beat-isolate.sh)
#   3. deps         npm ci fresco (node_modules NO se copia — ver .worktreeinclude)
#
# NO aborta ante un fallo: corre todo y reporta ✓/✗ por paso, para que veas el
# estado completo en el segundo 0 (no a los 20 minutos al levantar).
# Se dispara desde ~/.config/worktrunk/config.toml → post-start del back.
# ─────────────────────────────────────────────────────────────────────────────

# Re-exec con un bash moderno si el actual es viejo (macOS /bin/bash es 3.2; los
# iconos $'\u…' necesitan ≥4.2).
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  for b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [ -x "$b" ] && exec "$b" "$0" "$@"
  done
fi
set +e

WT_DIR="$(pwd)"
SCRIPTS="$HOME/.config/worktrunk/scripts"

# ── Identidad del par (misma derivación que beat-isolate) ────────────────────
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
MAIN_REPO="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
WT_NAME="$(basename "$WT_DIR")"
MAIN_NAME="$(basename "$MAIN_REPO")"
SUFFIX="${WT_NAME#${MAIN_NAME}.}"
PARENT="$(dirname "$MAIN_REPO")"
# El hook corre desde el BACK (config scopeado a apprecio-pulse); el par es la app.
APP_WT="$PARENT/app-rr-cesar.${SUFFIX}"

# ── Iconos Nerd Font (DankMono NF) + color ───────────────────────────────────
I_OK=$''; I_NO=$''; I_WARN=$''
I_BR=$''; I_KEY=$''; I_CUBE=$''; I_PKG=$''
I_DB=$''; I_BOLT=$''; I_RKT=$''; I_SPIN=$'⟳'
g=$'\e[32m'; r=$'\e[31m'; y=$'\e[33m'; dim=$'\e[2m'; bld=$'\e[1m'; z=$'\e[0m'
RULE="${dim}──────────────────────────────────────────────────${z}"
allok=1

row()     { printf '   %s  %s  %-11s %s%s%s\n' "$1" "$2" "$3" "$dim" "$4" "$z"; }
ok_row()  { row "${g}${I_OK}${z}" "$1" "$2" "$3"; }
bad_row() { row "${r}${I_NO}${z}" "$1" "$2" "${r}$3${z}"; allok=0; }

printf '\n %s%s%s %sPreparando worktree · beat%s  %s%s%s\n' "$bld" "$I_BR" "$z" "$bld" "$z" "$dim" "$SUFFIX" "$z"
printf '%s\n' "$RULE"

# 1) secrets — copy-ignored (back + app)
back_sec=1; app_sec=1
wt step copy-ignored >/dev/null 2>&1 || back_sec=0
if [ -d "$APP_WT" ]; then ( cd "$APP_WT" && wt step copy-ignored >/dev/null 2>&1 ) || app_sec=0; fi
if [ "$back_sec" = 1 ] && [ "$app_sec" = 1 ]; then
  ok_row "$I_KEY" "secrets" ".env · functions/.env (back + app)"
else
  bad_row "$I_KEY" "secrets" "copy-ignored falló (back=$back_sec app=$app_sec)"
fi

# 2) aislado — beat-isolate (slot, puertos, config.toml, .env back + app)
ISO_OUT="$(bash "$SCRIPTS/beat-isolate.sh" 2>&1)"; iso_rc=$?
if [ "$iso_rc" -eq 0 ] && [ -f "$WT_DIR/.worktree-slot" ]; then
  SLOT="$(tr -d '[:space:]' < "$WT_DIR/.worktree-slot")"
  API="$(grep -oE '127\.0\.0\.1:[0-9]+' "$WT_DIR/.env" 2>/dev/null | head -1 | grep -oE '[0-9]+$')"
  VITE="$(grep -E '^VITE_PORT=' "$WT_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
  ok_row "$I_CUBE" "aislado" "slot $SLOT · supabase :${API:-?} · vite :${VITE:-?}"
else
  bad_row "$I_CUBE" "aislado" "$(printf '%s' "$ISO_OUT" | tail -1)"
fi

# 3) deps — npm ci fresco (node_modules no se copia)
npm_ci_in() {  # dir label
  [ -f "$1/package.json" ] || return 0
  printf '   %s%s%s  %s  %-11s %snpm ci…%s' "$dim" "$I_SPIN" "$z" "$I_PKG" "$2" "$dim" "$z"
  if ( cd "$1" && npm ci >/dev/null 2>&1 ); then printf '\r'; ok_row "$I_PKG" "$2" "npm ci"
  else printf '\r'; bad_row "$I_PKG" "$2" "npm ci falló (lock desincronizado o red)"; fi
}
npm_ci_in "$WT_DIR" "deps back"
[ -d "$APP_WT" ] && npm_ci_in "$APP_WT" "deps app"

# ── footer ───────────────────────────────────────────────────────────────────
printf '%s\n' "$RULE"
if [ "$allok" = 1 ]; then
  printf ' %s%s listo para trabajar%s\n' "$g" "$I_RKT" "$z"
  printf '   %s%s%s supabase start      %s%s%s ⌘R npm run dev\n\n' "$dim" "$I_DB" "$z" "$dim" "$I_BOLT" "$z"
else
  printf ' %s%s revisá los %s%s%s de arriba antes de levantar%s\n\n' "$y" "$I_WARN" "$r" "$I_NO" "$y" "$z"
fi
