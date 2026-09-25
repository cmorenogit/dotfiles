#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-base-health.sh — Verifica que las BASES de Beat (back + app) estén sanas
# ANTES de crear un worktree. Se llama desde ~/.config/worktrunk/config.toml →
# [projects."…apprecio-pulse"] pre-switch. pre-* bloquea: exit 1 aborta la creación.
#
# Por qué: el 15/16-sep-2026 dos sesiones corrieron `git checkout <ref> -- .` en la
# base y la dejaron con 746 archivos del padre staged sobre `main`. Nadie lo vio en
# 9 días, y todo worktree nuevo leía de esa base (config.toml, .env) o partía de su
# `main` atrasado. Este chequeo corta la propagación.
#
#   base sucia (cambios trackeados)        → ABORTA y lista los archivos
#   `main` atrasado y base limpia           → pull --ff-only (se actualiza sola)
#   sin red / fetch falla                   → solo AVISA (no bloquea el trabajo en paralelo)
#   base en otra rama que no es main        → solo AVISA
#
# Args: $1 = {{ target_worktree_path }} — vacío al CREAR; con valor al cambiar a un
#       worktree existente (en ese caso no hay nada que verificar → sale 0).
# ─────────────────────────────────────────────────────────────────────────────
set +e

# wt ya escapa las variables para el shell: el template va SIN comillas. Si alguien lo
# vuelve a entrecomillar, el vacío llega como el literal '' — se trata igual que vacío.
case "${1:-}" in ""|"''") ;; *) exit 0 ;; esac

BACK="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)"
APP="$HOME/Code/work/rr-project/app-rr-cesar"
fail=0

check_base() {
  local dir="$1" label="$2" branch dirty behind
  [ -d "$dir/.git" ] || return 0
  branch="$(git -C "$dir" branch --show-current)"
  dirty="$(git -C "$dir" status --porcelain --untracked-files=no)"
  if [ -n "$dirty" ]; then
    echo "✗ [base-health] $label ($dir) tiene cambios trackeados — la base es SOLO LECTURA:"
    echo "$dirty" | head -10 | sed 's/^/    /'
    [ "$(echo "$dirty" | wc -l)" -gt 10 ] && echo "    … ($(echo "$dirty" | wc -l | tr -d ' ') en total)"
    echo "  Revisá su origen antes de limpiar (git -C \"$dir\" diff --cached --stat)."
    echo "  Si no es trabajo tuyo: git -C \"$dir\" reset --hard origin/main  (desde tu terminal)."
    fail=1
    return
  fi
  local to=""; command -v timeout >/dev/null 2>&1 && to="timeout 20"
  if ! $to git -C "$dir" fetch -q origin 2>/dev/null; then
    echo "⚠ [base-health] $label: fetch falló (¿sin red?) — sigo sin verificar si está al día."
    return
  fi
  if [ "$branch" != "main" ]; then
    echo "⚠ [base-health] $label está en '$branch', no en main — la base debería quedarse en main."
    return
  fi
  behind="$(git -C "$dir" rev-list --count main..origin/main 2>/dev/null)"
  if [ "${behind:-0}" -gt 0 ]; then
    if git -C "$dir" merge -q --ff-only origin/main 2>/dev/null; then
      echo "✓ [base-health] $label: main avanzó $behind commits (ff-only)."
    else
      echo "⚠ [base-health] $label: main va $behind commits detrás y no se pudo hacer ff-only."
    fi
  fi
}

check_base "$BACK" "back (back-pulse-cesar)"
check_base "$APP" "app (app-rr-cesar)"

# Slots de aislamiento (MAX_SLOTS de beat-isolate.sh). Sin slot libre, beat-isolate falla DESPUÉS
# de crear el worktree y éste queda apuntando al stack de la base (RYR-298, 14-sep-2026).
MAX_SLOTS=20
used=$(for wt in $(git -C "$BACK" worktree list --porcelain | awk '/^worktree /{print $2}'); do
  [ -f "$wt/.worktree-slot" ] && echo x; done | wc -l | tr -d ' ')
if [ "$used" -ge "$MAX_SLOTS" ]; then
  echo "✗ [base-health] Sin slots libres ($used/$MAX_SLOTS): el worktree nacería SIN aislar, sobre el stack de la base."
  echo "  Liberá uno con 'wt remove <rama>' (revisá antes que no tenga WIP sin commitear)."
  fail=1
elif [ "$used" -ge $((MAX_SLOTS - 2)) ]; then
  echo "⚠ [base-health] Quedan $((MAX_SLOTS - used)) slots libres ($used/$MAX_SLOTS)."
fi

[ "$fail" -eq 1 ] && echo "✗ [base-health] Creación abortada: limpiá la base y reintentá."
exit "$fail"
