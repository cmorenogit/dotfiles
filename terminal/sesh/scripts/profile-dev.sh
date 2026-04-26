#!/usr/bin/env zsh
# Profile dev workspace: claude (left) + npm run dev (right)

SESSION="profile-dev"
DIR="$HOME/Code/personal/app-profile"

sleep 0.8

# Rename current window
tmux rename-window -t "$SESSION" "profile"

# Current (left) pane: Claude Code with last session
tmux send-keys -t "$SESSION" "cl -c" Enter

# Create right pane: npm run dev
tmux split-window -h -t "$SESSION" -c "$DIR"
sleep 0.5
tmux send-keys -t "$SESSION.2" "npm run dev" Enter

# Focus left pane (claude)
tmux select-pane -t "$SESSION.1"
