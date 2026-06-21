#!/usr/bin/env bash
# linear-scan — foto rápida del inbox de notificaciones de Linear.
# Read-only contra Linear (una query). Estado (cursor) en ~/.claude/cache/linear-state/scan-cursor.json
# Key igual que linear-write-guard.sh: env LINEAR_API_KEY o keychain `linear-api-key`.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENDPOINT="https://api.linear.app/graphql"
STATE_DIR="${HOME}/.claude/cache/linear-state"
export CURSOR_FILE="${STATE_DIR}/scan-cursor.json"
export TZ_OFFSET="-05"   # GMT-5 fijo (Colombia/Perú — sin DST)

KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null || true)}"
[ -n "${KEY:-}" ] || { echo "✗ No hay LINEAR_API_KEY (env ni keychain 'linear-api-key')." >&2; exit 1; }

export SINCE_OVERRIDE=""
case "${1:-}" in
  "")          ;;
  --since)     export SINCE_OVERRIDE="${2:-}";;
  --since=*)   export SINCE_OVERRIDE="${1#*=}";;
  -h|--help)   echo "uso: scan.sh [--since 24h|3d|7d]   (sin args = delta desde el último scan)"; exit 0;;
  *)           echo "uso: scan.sh [--since 24h|3d|7d]" >&2; exit 2;;
esac

mkdir -p "$STATE_DIR"

RESP="$(curl -sf -m 20 "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: $KEY" \
  --data '{"query":"{ notifications(first: 150) { nodes { __typename ... on IssueNotification { type readAt createdAt issue { identifier title state { name } assignee { name displayName } } } } } }"}')" \
  || { echo "✗ Falló la consulta a Linear (red o key inválida)." >&2; exit 1; }

printf '%s' "$RESP" | python3 "$HERE/format.py"
