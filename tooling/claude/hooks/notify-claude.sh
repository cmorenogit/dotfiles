#!/bin/bash
# Notificaciones macOS para eventos de Claude Code
# Rate limiting: max 1 notificación cada 5 segundos
# Timeout: osascript max 3 segundos

LOCK_DIR="/tmp/claude-notify"
LOCK_FILE="$LOCK_DIR/last"
mkdir -p "$LOCK_DIR"

# Rate limiting: ignorar si última notificación fue hace menos de 5 seg
if [ -f "$LOCK_FILE" ]; then
  LAST=$(cat "$LOCK_FILE" 2>/dev/null)
  NOW=$(date +%s)
  if [ $((NOW - LAST)) -lt 5 ]; then
    exit 0
  fi
fi

INPUT=$(cat)

# Extraer campos en una sola llamada a jq
eval "$(echo "$INPUT" | jq -r '@sh "RAW_TYPE=\(.hook_event_name // "Unknown") NTYPE=\(.notification_type // "") RAW_MSG=\(.message // "")"')"

# Traducir evento a español + asignar sonido
case "$RAW_TYPE:$NTYPE" in
  StopFailure:*)                  TYPE="Error";           MSG="Falló la respuesta";         SOUND="Basso" ;;
  Notification:idle_prompt)       TYPE="Esperando input"; MSG="Claude espera tu respuesta"; SOUND="Purr"  ;;
  Notification:permission_prompt) TYPE="Pide permiso";    MSG="$RAW_MSG";                   SOUND="Funk"  ;;
  *)                              TYPE="$RAW_TYPE";       MSG="${RAW_MSG:-Evento}";          SOUND="Pop"   ;;
esac

# Contexto tmux: sesion + ventana
if [ -n "$TMUX_PANE" ]; then
  TMUX_SOCK="${TMUX%%,*}"
  LABEL=$(command tmux -S "$TMUX_SOCK" display-message -t "$TMUX_PANE" -p '#{session_name}/#{window_name}' 2>/dev/null)
else
  LABEL="claude"
fi

# Sanitizar para osascript
MSG="${MSG//\\/\\\\}"
MSG="${MSG//\"/\\\"}"
TYPE="${TYPE//\"/\\\"}"
LABEL="${LABEL//\"/\\\"}"

# Registrar timestamp antes de notificar
date +%s > "$LOCK_FILE"

# Timeout de 3 segundos para osascript
timeout 3 osascript -e "display notification \"$MSG\" with title \"[$LABEL] $TYPE\" sound name \"$SOUND\"" 2>/dev/null
