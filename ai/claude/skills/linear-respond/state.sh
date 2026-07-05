#!/usr/bin/env bash
# linear-respond — estado del issue para readiness (identifier · state · url), en vivo.
# Read-only contra la GraphQL API de Linear (una query). Sin binario externo.
# Key: env LINEAR_API_KEY o keychain 'linear-api-key'.
set -euo pipefail
ENDPOINT="https://api.linear.app/graphql"

usage() { echo "uso: state.sh <ID>   (ej: state.sh RYR-154)"; }

RAW="${1:-}"
[ -n "$RAW" ] || { usage >&2; exit 2; }
case "$RAW" in -h|--help) usage; exit 0;; esac

NORM="$(printf '%s' "$RAW" | tr '[:lower:]' '[:upper:]')"
if [[ "$NORM" =~ ^([A-Z]+)-?([0-9]+)$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"; NUM="${BASH_REMATCH[2]}"
else
  echo "✗ ID inválido: '$RAW' (esperado PREFIJO-NÚMERO, ej RYR-154)." >&2; exit 2
fi

KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null || true)}"
[ -n "${KEY:-}" ] || { echo "✗ No hay LINEAR_API_KEY (env ni keychain 'linear-api-key')." >&2; exit 1; }

QUERY="{ issues(filter: { team: { key: { eq: \"$PREFIX\" } }, number: { eq: $NUM } }, first: 1) { nodes { identifier state { name } url } } }"
BODY="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}))' "$QUERY")"

RESP="$(curl -sf -m 20 "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: $KEY" \
  --data "$BODY")" \
  || { echo "✗ Falló la consulta a Linear (red o key inválida)." >&2; exit 1; }

printf '%s' "$RESP" | ID="$PREFIX-$NUM" python3 -c '
import sys, os, json
r = json.load(sys.stdin)
if r.get("errors"):
    sys.exit("✗ Linear devolvió errores: " + "; ".join(e.get("message", "?") for e in r["errors"]))
n = (((r.get("data") or {}).get("issues") or {}).get("nodes")) or []
if not n:
    sys.exit("✗ No encontré " + os.environ.get("ID", "el issue") + " (¿ID correcto? ¿acceso al team?).")
i = n[0]
ident = i.get("identifier")
state = (i.get("state") or {}).get("name") or "—"
url = i.get("url") or ""
print(f"{ident} · {state} · {url}")
'
