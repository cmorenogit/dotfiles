#!/usr/bin/env bash
#
# fix-bd-precommit-hook.sh
#
# Propósito:
#   Arregla el hook de pre-commit generado por beads (bd) que quedó roto
#   en la versión 1.0.2. El hook ejecuta `bd sync --flush-only` pero ese
#   comando ya no existe en beads 1.0.2 con backend Dolt, por lo que
#   cualquier `git commit` en un repo con beads falla.
#
# Qué hace:
#   1. Recorre los directorios pasados como argumentos (o por default
#      ~/Code/work y ~/Code/personal).
#   2. Encuentra repos que tengan .beads/ y .git/hooks/pre-commit.
#   3. Si el hook contiene "bd sync --flush-only", hace backup (.bak) y
#      reemplaza por "bd export -o <path>/issues.jsonl" (el fix oficial
#      del proyecto, referenciado abajo).
#   4. Idempotente: si el hook ya está arreglado, lo ignora.
#
# Fuentes (por qué este fix es el correcto):
#   - Issue #1863: https://github.com/steveyegge/beads/issues/1863
#     Reporta que bd sync es no-op en backend Dolt ("Dolt persists writes
#     immediately") y recomienda bd export como reemplazo.
#   - PR #1919: cierra el issue en main, pero aún no hay release estable
#     con el fix (última release estable: 1.0.2 de abril 2025).
#
# Naturaleza temporal:
#   Este script es un PARCHE. Cuando el proyecto beads saque una versión
#   estable con el hook corregido upstream:
#     brew upgrade bd
#     bd init --force   # en cada repo, para regenerar hook correcto
#   Después de eso, este script queda obsoleto y debe eliminarse de
#   ~/.claude/scripts/ para evitar confusión.
#
# Uso:
#   fix-bd-precommit-hook.sh                      # directorios por default
#   fix-bd-precommit-hook.sh ~/otra/carpeta       # directorio específico
#   fix-bd-precommit-hook.sh --dry-run            # solo reporta, no toca
#
# Seguridad:
#   - Hace backup del hook original (.bak) antes de cambiar.
#   - Solo toca .git/hooks/pre-commit (local al clon, no se commitea).
#   - Re-ejecutarlo no causa daño: detecta y omite los ya arreglados.
#
set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  shift
fi

ROOTS=("$@")
if [ ${#ROOTS[@]} -eq 0 ]; then
  ROOTS=("$HOME/Code/work" "$HOME/Code/personal")
fi

OLD_LINE='bd sync --flush-only'
FIXED=0
ALREADY_OK=0
SKIPPED=0
NO_HOOK=0

echo "=== fix-bd-precommit-hook.sh ==="
echo "Directorios a revisar: ${ROOTS[*]}"
$DRY_RUN && echo "MODO: dry-run (no modifica archivos)"
echo

for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || { echo "Skip: $root (no existe)"; continue; }

  # Encontrar repos con .beads/ (solo nivel 1, que son los repos base)
  while IFS= read -r -d '' beads_dir; do
    repo_dir=$(dirname "$beads_dir")
    # Saltar si no es un repo git con .git/ como directorio (worktrees heredan el hook)
    [ -d "$repo_dir/.git" ] || { SKIPPED=$((SKIPPED+1)); continue; }

    hook="$repo_dir/.git/hooks/pre-commit"
    if [ ! -f "$hook" ]; then
      echo "  [no-hook] $repo_dir — no tiene pre-commit hook"
      NO_HOOK=$((NO_HOOK+1))
      continue
    fi

    if grep -qF "$OLD_LINE" "$hook"; then
      if $DRY_RUN; then
        echo "  [fixable] $repo_dir — hook tiene '$OLD_LINE'"
      else
        cp "$hook" "$hook.bak"
        # Reemplaza la línea del comando + los mensajes de error que lo referencian.
        # Usamos perl por portabilidad (sed -i difiere entre macOS/GNU).
        perl -i -pe "s|bd sync --flush-only|bd export -o \"\\\$BEADS_DIR/issues.jsonl\"|g; s|Failed to flush bd changes to JSONL|Failed to export bd issues to JSONL|g; s|Run 'bd sync --flush-only' manually to diagnose|Run 'bd export -o \\\$BEADS_DIR/issues.jsonl' manually to diagnose|g" "$hook"
        echo "  [FIXED]   $repo_dir (backup: $hook.bak)"
      fi
      FIXED=$((FIXED+1))
    else
      echo "  [ok]      $repo_dir — hook ya arreglado o no aplica"
      ALREADY_OK=$((ALREADY_OK+1))
    fi
  done < <(find "$root" -maxdepth 2 -type d -name ".beads" -print0 2>/dev/null)
done

echo
echo "=== Resumen ==="
$DRY_RUN && echo "  (dry-run — no se modificó nada)"
echo "  Arreglados:     $FIXED"
echo "  Ya estaban OK:  $ALREADY_OK"
echo "  Sin hook:       $NO_HOOK"
echo "  Saltados:       $SKIPPED"
