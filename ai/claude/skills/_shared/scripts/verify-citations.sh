#!/bin/bash
# verify-citations.sh — nivel 3 de la escalera de enforcement (linear-contract).
# Verifica que cada cita `file:línea` de un borrador exista en el código real.
# El LLM-judge valida la FORMA de la evidencia; este script valida la EVIDENCIA.
#
# Uso:
#   verify-citations.sh <borrador.md> <repo-dir> [ref]
#     borrador.md : archivo con el borrador (citas tipo `path/file.ext:123`)
#     repo-dir    : clone local del repo (read-only; usa git show, no checkout)
#     ref         : rama/SHA a verificar (default: HEAD)
#
# Salida: una línea por cita → OK | FAIL_NO_FILE | FAIL_NO_LINE
# Exit code: 0 si todas OK, 1 si alguna falla, 2 error de uso.
# Regla del gate: cualquier FAIL → el APPROVE degrada a CONDITIONS con ⚠️ cita no verificable.

set -u
DRAFT="${1:?uso: verify-citations.sh <borrador.md> <repo-dir> [ref]}"
REPO="${2:?falta repo-dir}"
REF="${3:-HEAD}"

[ -f "$DRAFT" ] || { echo "ERROR: borrador no existe: $DRAFT"; exit 2; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: no es repo git: $REPO"; exit 2; }

FAILS=0
CHECKED=0

while read -r cite; do
  [ -z "$cite" ] && continue
  file="${cite%:*}"
  line="${cite##*:}"
  CHECKED=$((CHECKED+1))
  if ! git -C "$REPO" cat-file -e "$REF:$file" 2>/dev/null; then
    echo "FAIL_NO_FILE  $cite"
    FAILS=$((FAILS+1))
    continue
  fi
  total=$(git -C "$REPO" show "$REF:$file" | wc -l | tr -d ' ')
  if [ "$line" -gt "$total" ]; then
    echo "FAIL_NO_LINE  $cite (archivo tiene $total líneas)"
    FAILS=$((FAILS+1))
  else
    echo "OK            $cite"
  fi
done < <(grep -oE '[A-Za-z0-9_./-]+\.[a-z]{1,5}:[0-9]+' "$DRAFT" | sort -u)

echo "---"
echo "citas: $CHECKED · fails: $FAILS"
[ "$FAILS" -eq 0 ]
