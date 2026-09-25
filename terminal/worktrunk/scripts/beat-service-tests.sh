#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-service-tests.sh — Corre los service tests de Beat con el stack de test RECIÉN arrancado
# y con un candado: el stack de test (:44321) es GLOBAL, compartido por todos los worktrees.
#
# Por qué: dos sesiones corriendo service tests a la vez se pisan los resets (RYR-286: "bloqueado,
# lo usa otra sesión"; PLA-29: "prohibido :44321, lo comparte otra sesión"), y un stack reusado en
# caliente dio ~1.344 rojos falsos. Con sesiones en paralelo (Supacode) esto se vuelve frecuente.
#
# Uso (desde el worktree del back):  beat-service-tests.sh [--wait] [args para run-service-tests.sh]
#   sin --wait: si otro worktree tiene el stack, informa quién y sale 3 (no espera).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

LOCK="/tmp/beat-test-stack.lock"
WAIT=0
[ "${1:-}" = "--wait" ] && { WAIT=1; shift; }
[ -f scripts/run-service-tests.sh ] || { echo "ERROR: corré desde la raíz del worktree del back"; exit 2; }

take_lock() {
  if mkdir "$LOCK" 2>/dev/null; then
    printf '%s\n%s\n%s\n' "$$" "$PWD" "$(date '+%H:%M:%S')" > "$LOCK/owner"
    return 0
  fi
  local pid; pid="$(sed -n 1p "$LOCK/owner" 2>/dev/null)"
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then   # dueño muerto: candado huérfano
    rm -rf "$LOCK"; take_lock; return $?
  fi
  return 1
}

until take_lock; do
  owner="$(sed -n 2p "$LOCK/owner" 2>/dev/null)"; since="$(sed -n 3p "$LOCK/owner" 2>/dev/null)"
  if [ "$WAIT" = "0" ]; then
    echo "✗ El stack de test (:44321) lo está usando $owner (desde $since). Esperá o corré con --wait."
    exit 3
  fi
  echo "… esperando el stack de test (lo usa $owner desde $since)"; sleep 30
done
trap 'rm -rf "$LOCK"' EXIT INT TERM

echo "[beat-service-tests] stack tomado por $PWD — arranque limpio (nunca reset en caliente)"
bash scripts/test-supabase-stop.sh >/dev/null 2>&1
bash scripts/run-service-tests.sh "$@"
rc=$?
bash scripts/test-supabase-stop.sh >/dev/null 2>&1
exit "$rc"
