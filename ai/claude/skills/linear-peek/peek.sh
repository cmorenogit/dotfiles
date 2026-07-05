#!/usr/bin/env bash
# linear-peek — vuelca los comentarios de UN issue de Linear en una ventana de tiempo (verbatim, GMT-5).
# Read-only contra Linear (una query). Sin cursor, sin estado: cada corrida es una foto del hilo.
# Default = lo de HOY; ampliable (Nd / Nh / all). Key igual que scan: env LINEAR_API_KEY o keychain.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENDPOINT="https://api.linear.app/graphql"
export TZ_OFFSET="-05"   # GMT-5 fijo (Colombia/Perú — sin DST)

usage() { echo "uso: peek.sh <ID> [ventana]   ventana = (vacío)=hoy · 2d · 12h · 7d · all   (ej: peek.sh RYR-131 3d)"; }

RAW="${1:-}"
[ -n "$RAW" ] || { usage >&2; exit 2; }
case "$RAW" in -h|--help) usage; exit 0;; esac

export PEEK_WINDOW="${2:-}"   # validada en format.py
NORM="$(printf '%s' "$RAW" | tr '[:lower:]' '[:upper:]')"   # acepta ryr131 / RYR131 / ryr-131 / RYR-131
if [[ "$NORM" =~ ^([A-Z]+)-?([0-9]+)$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"; NUM="${BASH_REMATCH[2]}"
else
  echo "✗ ID inválido: '$RAW' (esperado PREFIJO-NÚMERO, ej PRO-90 o pro90)." >&2; exit 2
fi

KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null || true)}"
[ -n "${KEY:-}" ] || { echo "✗ No hay LINEAR_API_KEY (env ni keychain 'linear-api-key')." >&2; exit 1; }

# last:100 + orderBy:createdAt → trae los 100 comentarios más recientes por creación (no por updatedAt).
# Igual reordenamos en format.py: no confiamos en el orden de entrega.
QUERY="{ issues(filter: { team: { key: { eq: \"$PREFIX\" } }, number: { eq: $NUM } }, first: 1) { nodes { identifier title url description state { name } assignee { displayName name } comments(last: 100, orderBy: createdAt) { nodes { body createdAt user { displayName name } parent { id } } } } } }"
BODY="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}))' "$QUERY")"

RESP="$(curl -sf -m 20 "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: $KEY" \
  --data "$BODY")" \
  || { echo "✗ Falló la consulta a Linear (red o key inválida)." >&2; exit 1; }

printf '%s' "$RESP" | ID="$PREFIX-$NUM" python3 "$HERE/format.py"
