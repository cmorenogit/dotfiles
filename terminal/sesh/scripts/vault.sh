#!/usr/bin/env zsh
# Vault workspace: pi en vault (left) + learning notes (right)

SESSION="vault"
DIR_VAULT="$HOME/Code/_vault"
DIR_LEARNING="$HOME/Code/_vault/_personal/learning"

sleep 0.5

# Rename current window
tmux rename-window -t "$SESSION" "vault"

# Current (left) pane: cl (Claude Code) in vault
cd "$DIR_VAULT"
tmux send-keys -t "$SESSION" "cl -r" Enter

# Right pane: git pull + lazygit en _vault
tmux split-window -h -t "$SESSION" -c "$DIR_VAULT"
sleep 0.3
tmux send-keys -t "$SESSION.2" "git pull origin && lg" Enter

# Focus left pane (pi)
tmux select-pane -t "$SESSION.1"
