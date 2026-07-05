#!/usr/bin/env bash
# linear-lore — trae issue + hilo COMPLETO (con comment_id para citar), en GMT-5.
# Read-only contra la GraphQL API de Linear (una query). Sin binario externo (mismo patrón que peek/scan).
# Key: env LINEAR_API_KEY o keychain 'linear-api-key'.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENDPOINT="https://api.linear.app/graphql"
export TZ_OFFSET="-05"   # GMT-5 fijo (Colombia/Perú — sin DST)

usage() { echo "uso: fetch.sh <ID>   (ej: fetch.sh RYR-154 · acepta ryr154 / RYR154 / ryr-154)"; }

RAW="${1:-}"
[ -n "$RAW" ] || { usage >&2; exit 2; }
case "$RAW" in -h|--help) usage; exit 0;; esac

NORM="$(printf '%s' "$RAW" | tr '[:lower:]' '[:upper:]')"
if [[ "$NORM" =~ ^([A-Z]+)-?([0-9]+)$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"; NUM="${BASH_REMATCH[2]}"
else
  echo "✗ ID inválido: '$RAW' (esperado PREFIJO-NÚMERO, ej RYR-154 o ryr154)." >&2; exit 2
fi

KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null || true)}"
[ -n "${KEY:-}" ] || { echo "✗ No hay LINEAR_API_KEY (env ni keychain 'linear-api-key')." >&2; exit 1; }

# last:100 + orderBy:createdAt → los 100 comentarios más recientes por creación. Trae 'id' (= comment_id
# para citar). Reordenamos en format.py: no confiamos en el orden de entrega de Linear.
QUERY="{ issues(filter: { team: { key: { eq: \"$PREFIX\" } }, number: { eq: $NUM } }, first: 1) { nodes { identifier title url description state { name } assignee { displayName name } comments(last: 100, orderBy: createdAt) { nodes { id body createdAt user { displayName name } parent { id } } pageInfo { hasNextPage } } } } }"
BODY="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}))' "$QUERY")"

RESP="$(curl -sf -m 20 "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: $KEY" \
  --data "$BODY")" \
  || { echo "✗ Falló la consulta a Linear (red o key inválida)." >&2; exit 1; }

printf '%s' "$RESP" | ID="$PREFIX-$NUM" python3 "$HERE/format.py"
