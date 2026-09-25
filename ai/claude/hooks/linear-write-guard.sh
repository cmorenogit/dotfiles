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

# En modo bypassPermissions un "ask" se auto-aprueba (verificado 2026-09-25: el payload trae
# permission_mode y el ask no muestra diálogo). Ahí el guard NIEGA: el agente deja el borrador
# y César publica, o cambia de modo (Shift+Tab) para aprobar la llamada.
# Crear un issue (save_issue sin "id") siempre pide listar los tickets propuestos antes.
payload=$(cat)
mode=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("permission_mode",""))' 2>/dev/null)
creates=$(printf '%s' "$payload" | python3 -c '
import json,sys
d=json.load(sys.stdin); t=d.get("tool_name",""); i=d.get("tool_input") or {}
print("1" if t.endswith("save_issue") and not i.get("id") else "0")' 2>/dev/null)

reason="Guardrail never-post (linear-contract): publicar/editar/eliminar en Linear requiere confirmación humana explícita. César es el gate final. Mostrá el texto FINAL verbatim; 1 OK = 1 publicación (una edición posterior vuelve a requerir OK)."
[ "$creates" = "1" ] && reason="$reason Crear un issue: primero listá los tickets propuestos (título · por qué · dueño) y esperá el OK de César para cada uno; un hallazgo de otro dueño se le pregunta a ese dueño, no se crea."

if [ "$mode" = "bypassPermissions" ]; then
  decision="deny"
  reason="$reason [Modo bypass: el diálogo de confirmación no existe, así que se BLOQUEA. Dejá el borrador listo; César lo publica o cambia de modo y reintenta.]"
else
  decision="ask"
fi

python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":sys.argv[1],"permissionDecisionReason":sys.argv[2]}}, ensure_ascii=False))' "$decision" "$reason"
