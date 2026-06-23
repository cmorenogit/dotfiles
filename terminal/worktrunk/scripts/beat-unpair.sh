#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-unpair.sh — Espejo de beat-prep para la ELIMINACIÓN de un worktree Beat.
#
# Corre desde pre-remove del back (config.toml), ANTES de que wt borre el back.
# Mismo lenguaje visual que la creación (iconos NF, filas ✓/✗):
#   1. docker   para+borra los containers Supabase del slot (no dejar huérfanos)
#   2. app      remueve el worktree+rama par del app (modo SEGURO: si tiene
#               cambios sin commitear, lo DEJA y marca ✗ — no aborta)
# El back lo elimina wt a continuación. NO aborta nunca (sale 0): solo reporta.
#
# Args: $1 = branch (de {{ branch }})
# ─────────────────────────────────────────────────────────────────────────────

# Re-exec con bash moderno si el actual es viejo (macOS /bin/bash 3.2; $'\u…' ≥4.2).
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  for b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [ -x "$b" ] && exec "$b" "$0" "$@"
  done
fi
set +e

BRANCH="${1:-}"
WT_DIR="$(pwd)"

# ── Identidad del par (misma derivación que beat-prep) ───────────────────────
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
MAIN_REPO="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
WT_NAME="$(basename "$WT_DIR")"
MAIN_NAME="$(basename "$MAIN_REPO")"
SUFFIX="${WT_NAME#${MAIN_NAME}.}"
PARENT="$(dirname "$MAIN_REPO")"
APP_BASE="$PARENT/app-rr-cesar"
APP_WT="$APP_BASE.${SUFFIX}"
[ -z "$BRANCH" ] && BRANCH="$(git -C "$WT_DIR" branch --show-current 2>/dev/null)"

# ── Iconos Nerd Font (mismos codepoints que beat-prep) + color ───────────────
I_OK=$''; I_NO=$''; I_WARN=$''
I_BR=$''; I_DB=$''; I_CUBE=$''
g=$'\e[32m'; r=$'\e[31m'; y=$'\e[33m'; dim=$'\e[2m'; bld=$'\e[1m'; z=$'\e[0m'
RULE="${dim}──────────────────────────────────────────────────${z}"
allok=1

row()     { printf '   %s  %s  %-11s %s%s%s\n' "$1" "$2" "$3" "$dim" "$4" "$z"; }
ok_row()  { row "${g}${I_OK}${z}" "$1" "$2" "$3"; }
bad_row() { row "${r}${I_NO}${z}" "$1" "$2" "${r}$3${z}"; allok=0; }

printf '\n %s%s%s %sEliminando worktree · beat%s  %s%s%s\n' "$bld" "$I_BR" "$z" "$bld" "$z" "$dim" "$SUFFIX" "$z"
printf '%s\n' "$RULE"

# 1) docker — parar+borrar los containers del slot (no dejar huérfanos)
PID="$(tr -d '[:space:]' < "$WT_DIR/.supabase-project-id.local" 2>/dev/null)"
if [ -n "$PID" ]; then
  N="$(docker ps -aq --filter "name=_$PID" 2>/dev/null | grep -c .)"
  if [ "${N:-0}" -gt 0 ]; then
    if docker ps -aq --filter "name=_$PID" 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1; then
      ok_row "$I_DB" "docker" "$N containers del slot detenidos ($PID)"
    else
      bad_row "$I_DB" "docker" "no se pudieron borrar containers ($PID)"
    fi
  else
    ok_row "$I_DB" "docker" "sin containers activos del slot"
  fi
else
  ok_row "$I_DB" "docker" "sin stack aislado (nada que parar)"
fi

# 2) app — remover worktree+rama par (SEGURO: si hay cambios, conservar y marcar ✗)
if [ -d "$APP_WT" ]; then
  if [ -n "$(git -C "$APP_WT" status --porcelain 2>/dev/null)" ]; then
    bad_row "$I_CUBE" "app" "CONSERVADO: tiene cambios sin commitear → $APP_WT"
  elif git -C "$APP_BASE" worktree remove "$APP_WT" >/dev/null 2>&1; then
    if [ -n "$BRANCH" ] && git -C "$APP_BASE" branch -d "$BRANCH" >/dev/null 2>&1; then
      ok_row "$I_CUBE" "app" "worktree + rama par removidos (app-rr-cesar.${SUFFIX})"
    else
      ok_row "$I_CUBE" "app" "worktree par removido (rama conservada: no merged)"
    fi
  else
    bad_row "$I_CUBE" "app" "git worktree remove falló → $APP_WT"
  fi
else
  ok_row "$I_CUBE" "app" "sin par que remover"
fi

# ── footer ───────────────────────────────────────────────────────────────────
printf '%s\n' "$RULE"
if [ "$allok" = 1 ]; then
  printf ' %s%s el back se elimina a continuación (wt)%s\n\n' "$dim" "$I_BR" "$z"
else
  printf ' %s%s revisá los %s%s%s de arriba — el back se elimina igual%s\n\n' "$y" "$I_WARN" "$r" "$I_NO" "$y" "$z"
fi
exit 0
