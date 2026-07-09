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

# meeting-scribe (real-time transcription)
alias scribe="$HOME/Code/personal/meeting-scribe/.venv/bin/meeting-scribe"

# SSH Mini
alias mini="ssh mini"
alias hmini="herdr --remote mini --remote-keybindings server"

# herdr: gestión de sesiones nombradas en el server de mini.
# `herdr session <cmd>` solo opera sobre el server local a la máquina donde
# corre el comando, por eso hay que detectar si ya estamos en mini (correr
# directo) o en otra máquina (saltar por ssh).
_herdr_on_mini() {
  [[ "$(hostname -s)" == "Mac-mini-de-Cesar" ]]
}

hnew() {
  if [[ -z "$1" ]]; then
    echo "uso: hnew <nombre-sesion>"
    return 1
  fi
  if _herdr_on_mini; then
    herdr --session "$1"
  else
    herdr --remote mini --session "$1"
  fi
}

hls() {
  if _herdr_on_mini; then
    herdr session list
  else
    ssh mini herdr session list
  fi
}

hstop() {
  if [[ -z "$1" ]]; then
    echo "uso: hstop <nombre-sesion>"
    return 1
  fi
  if _herdr_on_mini; then
    herdr session stop "$1"
  else
    ssh mini herdr session stop "$1"
  fi
}

hrm() {
  if [[ -z "$1" ]]; then
    echo "uso: hrm <nombre-sesion>"
    return 1
  fi
  if _herdr_on_mini; then
    herdr session delete "$1"
  else
    ssh mini herdr session delete "$1"
  fi
}

# Keychain: desbloquear el login keychain (útil en sesiones SSH, pide password)
alias unlock="security unlock-keychain ~/Library/Keychains/login.keychain-db"
