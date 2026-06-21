#!/bin/bash
# never-post guardrail (linear-contract, núcleo #1).
# Toda escritura a Linear (save_* / delete_* / create_* del MCP linear) requiere
# confirmación humana explícita, sin importar el permission mode: fuerza el "ask".
# César es el gate final.
#
# Alcance (matcher en settings.json): mcp__linear__save_.*|delete_.*|create_.*
#   → cubre comment, issue, document, project, initiative, milestone, status_update,
#     label y attachment. Si Linear agrega una escritura save_/delete_/create_, queda
#     cubierta sola. (pm-agents-remote queda fuera a propósito: no se usa para escribir.)
#
# El CRITERIO de review (lección RYR-111: una review formal exige el issue en "In Review")
# NO vive acá — vive en la skill /linear-respond. El hook solo hace lo mecánico: confirmar.

cat >/dev/null  # consumir el payload del hook (stdin)

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Guardrail never-post (linear-contract): publicar/editar/eliminar en Linear requiere confirmación humana explícita. César es el gate final."}}
EOF
