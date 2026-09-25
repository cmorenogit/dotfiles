#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-spawn.sh — Crea el worktree de un issue de Beat y abre una sesión de Claude en Supacode
# dentro de ese worktree, corriendo `/implementar <ID>`. Una rama = un worktree = una sesión:
# las sesiones no crean ramas de otras sesiones; esto lo corre César.
#
# Uso (normalmente vía los alias de worktrunk: `wt issue …` / `wt issue-open …`):
#   beat-spawn.sh <rama> <ID> [--base <ref>] [--background]   crear worktree (wt switch -c) + sesión
#   beat-spawn.sh --open <rama> <ID> [--background]            nueva sesión en un worktree existente
#
# Verificado 25-sep-2026: un worktree creado con `wt switch -c` aparece en Supacode tras
# `supacode repo open <ruta>`, y `supacode tab new -w <id> -i <cmd>` corre el comando en esa rama.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

BASE_DIR="$HOME/Code/work/rr-project/back-pulse-cesar"
OPEN=0 BG="" BASE_REF="" CMD_OVERRIDE=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --open) OPEN=1; shift ;;
    --base) BASE_REF="$2"; shift 2 ;;
    --base=*) BASE_REF="${1#--base=}"; shift ;;
    --background) BG="--background"; shift ;;
    --cmd) CMD_OVERRIDE="$2"; shift 2 ;;   # solo para pruebas: reemplaza el comando de la pestaña
    *) args+=("$1"); shift ;;
  esac
done
[ ${#args[@]} -eq 2 ] || { echo "Uso: beat-spawn.sh [--open] <rama> <ID> [--base <ref>] [--background]"; exit 2; }
BRANCH="${args[0]}" ID="${args[1]}"

find_wt() { git -C "$BASE_DIR" worktree list --porcelain | awk -v b="branch refs/heads/$1" '/^worktree /{p=$2} $0==b{print p; exit}'; }

if [ "$OPEN" = "0" ]; then
  [ -n "$(find_wt "$BRANCH")" ] && { echo "Ya existe un worktree para $BRANCH: usá --open."; exit 2; }
  (cd "$BASE_DIR" && wt switch --create "$BRANCH" ${BASE_REF:+--base "$BASE_REF"} --no-cd -y) || { echo "✗ wt switch -c falló (mirá el mensaje de base-health)."; exit 1; }
fi
WT="$(find_wt "$BRANCH")"
[ -n "$WT" ] || { echo "✗ no encontré el worktree de $BRANCH"; exit 1; }

CMD="${CMD_OVERRIDE:-claude '/implementar $ID'}"
if [ -z "${SUPACODE_SOCKET_PATH:-}" ] || ! command -v supacode >/dev/null; then
  echo "Worktree listo: $WT"
  echo "No estás en Supacode: abrí una terminal ahí y corré  cd \"$WT\" && $CMD"
  exit 0
fi
supacode repo open "$WT" >/dev/null 2>&1
WID="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1].rstrip("/")+"/", safe=""))' "$WT")"
for _ in 1 2 3 4 5; do supacode worktree list 2>/dev/null | grep -qxF "$WID" && break; sleep 1; done
TAB="$(supacode tab new -w "$WID" $BG --title "$ID" -i "$CMD")" || { echo "✗ supacode no pudo abrir la pestaña"; exit 1; }
[ -z "$BG" ] && supacode worktree focus -w "$WID" >/dev/null 2>&1
echo "✓ $ID: worktree $WT · sesión de Claude abierta en Supacode (pestaña $TAB) con /implementar $ID"
