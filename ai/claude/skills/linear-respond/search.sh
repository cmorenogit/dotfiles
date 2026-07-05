#!/usr/bin/env bash
# linear-respond — dedup: busca issues por términos (searchIssues full-text, live).
# Reemplaza el 'issues search' (FTS5 local) del binario por la búsqueda nativa de Linear — siempre fresca.
# Read-only contra la GraphQL API de Linear. Key: env LINEAR_API_KEY o keychain 'linear-api-key'.
set -euo pipefail
ENDPOINT="https://api.linear.app/graphql"

usage() { echo 'uso: search.sh <términos>   (ej: search.sh "entrenamientos xp")'; }

TERM="${*:-}"
[ -n "$TERM" ] || { usage >&2; exit 2; }
case "$TERM" in -h|--help) usage; exit 0;; esac

KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null || true)}"
[ -n "${KEY:-}" ] || { echo "✗ No hay LINEAR_API_KEY (env ni keychain 'linear-api-key')." >&2; exit 1; }

# Variable GraphQL ($t) → sin problemas de escaping con comillas/acentos en los términos.
BODY="$(python3 -c 'import json,sys; print(json.dumps({"query":"query($t:String!){ searchIssues(term:$t, first:8){ nodes { identifier title state { name } url } } }","variables":{"t":sys.argv[1]}}))' "$TERM")"

RESP="$(curl -sf -m 20 "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: $KEY" \
  --data "$BODY")" \
  || { echo "✗ Falló la consulta a Linear (red o key inválida)." >&2; exit 1; }

printf '%s' "$RESP" | TERM="$TERM" python3 -c '
import sys, os, json
r = json.load(sys.stdin)
if r.get("errors"):
    sys.exit("✗ Linear devolvió errores: " + "; ".join(e.get("message", "?") for e in r["errors"]))
nodes = (((r.get("data") or {}).get("searchIssues") or {}).get("nodes")) or []
term = os.environ.get("TERM", "")
if not nodes:
    print(f"(sin coincidencias para «{term}»)"); sys.exit(0)
print(f"{len(nodes)} coincidencia(s) para «{term}»:")
for n in nodes:
    ident = n.get("identifier")
    state = (n.get("state") or {}).get("name") or "—"
    title = " ".join((n.get("title") or "").split())
    url = n.get("url") or ""
    print(f"  {ident} · {state} · {title}")
    print(f"      {url}")
'
