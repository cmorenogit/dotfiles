#!/usr/bin/env zsh
# Apprecio template: ventana Estado + ventana Linear, ambas con cl en el vault

SESSION="apprecio"
DIR_VAULT="$HOME/Code/_vault"

sleep 0.5

# Ventana 1: Estado — cl en el vault
tmux rename-window -t "$SESSION:1" "Estado"
cd "$DIR_VAULT"
tmux send-keys -t "$SESSION:1" "cl -r" Enter

# Ventana 2: Linear — cl en el vault
tmux new-window -t "$SESSION" -n "Linear" -c "$DIR_VAULT"
tmux send-keys -t "$SESSION:2" "cl -r" Enter

# Volver a la primera ventana
tmux select-window -t "$SESSION:1"
