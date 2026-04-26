# Enable aliases to be sudo’ed
alias sudo='sudo '

alias ..="cd .."
alias ...="cd ../.."
alias ls="eza $_EZA_PARAMS"
alias ll="eza -l $_EZA_PARAMS"
alias la="eza -lah $_EZA_PARAMS"
alias las="eza -lah -s modified --reverse $_EZA_PARAMS"
alias dops='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

# tmux
alias t='tmux'
alias tm='tmux new-session -A -s main'
alias doco='docker-compose'
alias ~="cd ~"
alias dotfiles='cd $DOTFILES_PATH'

# Git
alias gic="git commit -m"
alias gaa="git add -A"
alias gc='$DOTLY_PATH/bin/dot git commit'
alias gca="git add --all && git commit --amend --no-edit"
alias gco="git checkout"
alias gd='$DOTLY_PATH/bin/dot git pretty-diff'
alias gs="git status -sb"
alias gf="git fetch --all -p"
alias gps="git push"
alias gpsf="git push --force"
alias gpl="git pull --rebase --autostash"
alias gbc="git switch -c"
alias gb="git switch"
alias gl='$DOTLY_PATH/bin/dot git pretty-log'
alias cx='codex'
alias oc="opencode"
alias ocp="opencode -p"
alias cxp='codex exec --skip-git-repo-check '
alias ge='gemini'
alias gep='gemini -p'
alias cl="claude --dangerously-skip-permissions"
alias clp="claude -p --model sonnet"

# Utils
alias htop='glances'
alias k='kill -9'
alias c.='(code $PWD &>/dev/null &)'
alias z.='(zed $PWD &>/dev/null &)'
alias o.='open .'
alias up='dot package update_all'

# Proyectos
alias rr='./scripts/setup-local.sh'
alias rr-mcp='./scripts/toggle-mcp.sh'
alias rr-tunnel-start='./scripts/share-tunnel.sh start --build'
alias rr-tunnel='./scripts/share-tunnel.sh'

alias ta='tmux attach -t'
alias tn='tmux new-session -s'

# SSH Mini
alias mini="ssh mini"
