#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-migration-order.sh — ¿Las migraciones de esta rama entran en orden a producción?
#
# Por qué: `supabase db push` (production-deploy) SIN --include-all saltea en silencio toda
# migración con timestamp <= la última aplicada. Pasó en RYR-296 (08-sep) y en PLA-29/RYR-405
# (24-sep, lo detectó el QA de Ignacio en la iteración 3 con CI verde), y el trunk de RYR-286
# re-estampó a mano varias veces. Además dos PRs abiertos pueden estampar el mismo prefijo.
#
# Uso (desde un worktree del back):  bash ~/.config/worktrunk/scripts/beat-migration-order.sh
# Cuándo: antes de pedir QA/CR, después de cada `merge origin/main` y antes de promover a main.
#
#   FAIL  migración nueva con timestamp <= max(origin/main)   → re-estampar (al promover)
#   FAIL  mismo prefijo que una migración de otro PR abierto   → coordinar/re-estampar
#   WARN  timestamp a más de 30 días en el futuro
# Exit 1 si hay algún FAIL. Solo lectura (git fetch + gh).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="${BEAT_REPO:-ivaldovinos-app/apprecio-pulse}"
DIR="supabase/migrations"
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "ERROR: no estás en un repo git"; exit 2; }
[ -d "$DIR" ] || { echo "ERROR: no hay $DIR acá (¿es el worktree del back?)"; exit 2; }

git fetch -q origin main 2>/dev/null || echo "⚠ fetch falló: uso el origin/main local"
branch="$(git branch --show-current)"

ts() { sed -nE 's|.*/([0-9]{14})_.*|\1|p'; }
max_main="$(git ls-tree --name-only origin/main "$DIR/" | ts | sort | tail -1)"
mine="$(git diff --name-only --diff-filter=A origin/main...HEAD -- "$DIR/" | ts | sort)"

if [ -z "$mine" ]; then
  echo "✓ [migrations] $branch no agrega migraciones respecto de origin/main."
  exit 0
fi

others="$(gh pr list -R "$REPO" --state open --limit 100 --json number,headRefName,files \
  -q ".[] | select(.headRefName != \"$branch\") | .number as \$n | .files[].path
       | select(startswith(\"$DIR/\")) | \"\(\$n) \(.)\"" 2>/dev/null)"

future="$(date -u -v+30d +%Y%m%d%H%M%S 2>/dev/null || /bin/date -u -v+30d +%Y%m%d%H%M%S)"
fail=0
echo "[migrations] rama: $branch · max(origin/main) = $max_main · nuevas: $(echo "$mine" | wc -l | tr -d ' ')"
for t in $mine; do
  f="$(git diff --name-only --diff-filter=A origin/main...HEAD -- "$DIR/" | grep "/${t}_" | head -1)"
  if [ "$t" \< "$max_main" ] || [ "$t" = "$max_main" ]; then
    echo "  ✗ $f  <= max(main) $max_main → db push sin --include-all la SALTEA. Re-estampar por encima al promover."
    fail=1
  fi
  clash="$(echo "$others" | awk -v t="$t" 'index($2, "/" t "_") {print "#" $1 " " $2}')"
  if [ -n "$clash" ]; then
    echo "  ✗ $f  colisiona con: $clash"
    fail=1
  fi
  [ "$t" \> "$future" ] && echo "  ⚠ $f  está a más de 30 días en el futuro."
done
[ "$fail" -eq 0 ] && echo "✓ [migrations] orden OK contra origin/main y los PRs abiertos."
exit "$fail"
