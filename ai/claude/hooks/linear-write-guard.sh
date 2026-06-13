#!/bin/bash
# never-post guardrail (linear-contract, núcleo #1) — nivel 4 de la escalera de enforcement.
# Toda escritura a Linear (save_comment / save_issue) requiere confirmación humana explícita,
# sin importar el permission mode. No bloquea el uso legítimo: fuerza el "ask".
#
# v2 — review-state guard (lección RYR-111, 11-jun-2026):
# si el comentario es una REVIEW formal (veredicto APPROVE/CONDITIONS/CHANGES/MUST FIX...),
# valida que el issue esté en "In Review" antes de publicar. Una review formal respondida
# con el issue en In Progress rompe el flujo (QA de Julieth + revisión de Ignacio quedan
# fuera del ciclo). Fuentes de verdad, en orden:
#   1. API Linear en vivo (si LINEAR_API_KEY en env o keychain `linear-api-key`)
#   2. Snapshot fresco (<30 min) que el skill linear-respond persiste vía get_issue:
#      ~/.claude/cache/linear-state/{ISSUE}.json  → {"state":"In Review","checked_at":"<epoch>"}
#   3. Sin fuente → fail-closed: ⚠️ exige verificación manual en el prompt.
# La decisión SIEMPRE es "ask" (César es el gate final) — el hook informa, no sobrescribe.

INPUT=$(cat)

emit() {
  jq -cn --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
  exit 0
}

BASE="Guardrail never-post (linear-contract): publicar/editar en Linear requiere confirmación humana explícita. César es el gate final."

command -v jq >/dev/null 2>&1 || { cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Guardrail never-post (linear-contract): publicar/editar en Linear requiere confirmación humana explícita. César es el gate final."}}
EOF
exit 0; }

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.body // empty')
ISSUE=$(printf '%s' "$INPUT" | jq -r '.tool_input.issueId // empty')

# Solo el state-guard aplica a comentarios; save_issue/delete_comment → ask base.
[ "$TOOL" = "mcp__linear__save_comment" ] || emit "$BASE"

# ¿El body es una review formal? (veredictos + bloques de hallazgos)
if ! printf '%s' "$BODY" | grep -qE 'APPROVE WITH CONDITIONS|CHANGES REQUESTED|READY TO MERGE|MUST FIX|SHOULD FIX|\bAPPROVE\b'; then
  emit "$BASE"
fi

REVIEW_NOTE="Comentario tipo REVIEW detectado (lección RYR-111). Checklist: (1) issue en In Review, (2) la SOLICITUD de review menciona a @juli (QA) y a @ignacio (revisión) — pedida sin eso se devuelve, no se responde con veredicto."

# Edición de comentario sin issueId → no podemos resolver el issue: advertir.
[ -n "$ISSUE" ] || emit "⚠️ $REVIEW_NOTE No pude determinar el issue (edición sin issueId) — verificá el estado manualmente. · $BASE"

ALLOWED_STATE="In Review"
STATE=""
SOURCE=""

# Fuente 1: API en vivo
KEY="${LINEAR_API_KEY:-$(security find-generic-password -s linear-api-key -w 2>/dev/null)}"
if [ -n "$KEY" ]; then
  STATE=$(curl -sf -m 6 https://api.linear.app/graphql \
    -H "Authorization: $KEY" -H "Content-Type: application/json" \
    --data "{\"query\":\"{ issue(id: \\\"$ISSUE\\\") { state { name } } }\"}" \
    | jq -r '.data.issue.state.name // empty')
  [ -n "$STATE" ] && SOURCE="API en vivo"
fi

# Fuente 2: snapshot del skill (frescura 30 min)
if [ -z "$STATE" ]; then
  SNAP="$HOME/.claude/cache/linear-state/$ISSUE.json"
  if [ -f "$SNAP" ]; then
    CHECKED=$(jq -r '.checked_at // 0' "$SNAP" 2>/dev/null)
    NOW=$(date +%s)
    if [ "$CHECKED" -gt 0 ] 2>/dev/null && [ $((NOW - CHECKED)) -lt 1800 ]; then
      STATE=$(jq -r '.state // empty' "$SNAP" 2>/dev/null)
      [ -n "$STATE" ] && SOURCE="snapshot $(((NOW - CHECKED) / 60)) min"
    fi
  fi
fi

if [ -z "$STATE" ]; then
  emit "⚠️ $REVIEW_NOTE Estado del issue NO VERIFICABLE (sin API key ni snapshot fresco) — confirmá vos que $ISSUE esté en '$ALLOWED_STATE' antes de publicar. · $BASE"
elif [ "$STATE" = "$ALLOWED_STATE" ]; then
  emit "✅ Review formal: $ISSUE en '$STATE' ($SOURCE) — estado OK. Verificá que la SOLICITUD de review mencionara a @juli y @ignacio (criterio 9). · $BASE"
else
  emit "🛑 BLOQUEO DE PROCESO: $ISSUE está en '$STATE', no en '$ALLOWED_STATE' ($SOURCE). Una review formal con el issue fuera de In Review repite el error de RYR-111 — coordiná el cambio de estado (o respondé como nota de proceso, sin veredicto) antes de publicar. · $BASE"
fi
