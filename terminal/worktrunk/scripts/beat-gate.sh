#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-gate.sh — Corre el gate ADLC local EXACTAMENTE como lo corre CI (.github/workflows/gate.yml).
#
# Por qué: el gate local se alimentaba a mano y daba verdes falsos o rojos distintos a CI
# (sesiones RYR-208/286/287/300/PLA-29): sin los 3 argumentos, CHANGED_DIR con un solo archivo,
# `origin/` en el base ref, correr antes de commitear, spec path distinto al que extrae CI.
#
# Uso (desde el worktree, con TODO commiteado):
#   beat-gate.sh --pr <N>                  # body y base del PR real (lo más fiel a CI)
#   beat-gate.sh --body <archivo> [--base <rama>]   # antes de abrir el PR (base default: main)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PR="" BODY_FILE="" BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;;
    --body) BODY_FILE="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    *) echo "Uso: beat-gate.sh --pr <N> | --body <archivo> [--base <rama>]"; exit 2 ;;
  esac
done
[ -n "$PR" ] || [ -n "$BODY_FILE" ] || { echo "Uso: beat-gate.sh --pr <N> | --body <archivo> [--base <rama>]"; exit 2; }
[ -x scripts/adlc/gate-check.sh ] || [ -f scripts/adlc/gate-check.sh ] || { echo "ERROR: corré desde la raíz del worktree del back (falta scripts/adlc/gate-check.sh)"; exit 2; }

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "✗ Hay cambios trackeados sin commitear: el gate de CI evalúa lo commiteado. Commiteá y reintentá."
  git status --porcelain --untracked-files=no | head -10 | sed 's/^/    /'
  exit 2
fi

WORK="$(mktemp -d -t beat-gate)"
trap 'rm -rf "$WORK"' EXIT
if [ -n "$PR" ]; then
  gh pr view "$PR" --json body -q .body > "$WORK/pr-body.txt" || { echo "ERROR: no pude leer el PR #$PR"; exit 2; }
  [ -n "$BASE" ] || BASE="$(gh pr view "$PR" --json baseRefName -q .baseRefName)"
  head_pr="$(gh pr view "$PR" --json headRefOid -q .headRefOid)"
  [ "$head_pr" = "$(git rev-parse HEAD)" ] || echo "⚠ El HEAD local ($(git rev-parse --short HEAD)) no es el del PR (${head_pr:0:9}): ¿falta push?"
else
  cp "$BODY_FILE" "$WORK/pr-body.txt"
fi
BASE="${BASE:-main}"
BASE="${BASE#origin/}"
git fetch -q origin "$BASE" 2>/dev/null || echo "⚠ fetch de origin/$BASE falló: uso la ref local"

# Spec path: misma extracción que gate.yml (Promotion → multi · Retro → retro · línea Spec: · 1er docs/specs).
B="$WORK/pr-body.txt"
if grep -q '^## Promotion PR' "$B"; then SPEC="multi"
elif grep -q '^## ADLC Retro' "$B"; then SPEC="retro"
else
  SPEC="$(grep -oE '^[[:space:]]*Spec:[[:space:]]*`?docs/specs/[A-Za-z0-9._/-]+\.md' "$B" | grep -oE 'docs/specs/[A-Za-z0-9._/-]+\.md' | head -1)"
  [ -n "$SPEC" ] || SPEC="$(grep -oE 'docs/specs/[A-Za-z0-9._/-]+\.md' "$B" | head -1)"
fi
[ -n "$SPEC" ] || echo "⚠ El body no cita ningún docs/specs/*.md: CI va a dar 'Missing spec file path'."

# Archivos cambiados: igual que CI (diff contra origin/<base>, preservando la ruta), con el contenido de HEAD.
mkdir -p "$WORK/changed-files"
git diff --name-only "origin/${BASE}...HEAD" | while IFS= read -r f; do
  if git cat-file -e "HEAD:$f" 2>/dev/null; then
    mkdir -p "$WORK/changed-files/$(dirname "$f")"
    git show "HEAD:$f" > "$WORK/changed-files/$f"
  fi
done
echo "[beat-gate] base=$BASE · spec=${SPEC:-<ninguno>} · archivos=$(find "$WORK/changed-files" -type f | wc -l | tr -d ' ')"

GITHUB_BASE_REF="$BASE" bash scripts/adlc/gate-check.sh "$B" "$SPEC" "$WORK/changed-files"
