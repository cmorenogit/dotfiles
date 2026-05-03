#!/usr/bin/env zsh
# Uncomment for debuf with `zprof`
# zmodload zsh/zprof

# ZSH Ops
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FCNTL_LOCK
setopt +o nomatch
# setopt autopushd

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Start Zim
source "$ZIM_HOME/init.zsh"

# Async mode for autocompletion
ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_HIGHLIGHT_MAXLENGTH=300

source "$DOTFILES_PATH/shell/init.sh"

fpath=("$DOTFILES_PATH/shell/zsh/themes" "$DOTFILES_PATH/shell/zsh/completions" "$DOTLY_PATH/shell/zsh/themes" "$DOTLY_PATH/shell/zsh/completions" $fpath)

autoload -Uz promptinit && promptinit
prompt ${DOTLY_THEME:-codely}

source "$DOTLY_PATH/shell/zsh/bindings/dot.zsh"
source "$DOTLY_PATH/shell/zsh/bindings/reverse_search.zsh"
source "$DOTFILES_PATH/shell/zsh/key-bindings.zsh"

# opencode
export PATH=/Users/cmoreno/.opencode/bin:$PATH

# Agent Teams Lite (SDD) update
alias sdd-update="cd ~/Code/tools/agent-teams-lite && git pull && ./scripts/install.sh --agent claude-code"

# Obsidian vault
alias vault='cd ~/Code/_vault'

# worktrunk: Git worktree management for parallel AI agent workflows
eval "$(wt config shell init zsh)"

# Atuin - prueba temporal con Ctrl+G (Ctrl+R sigue siendo fzf)
eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
bindkey '^G' atuin-search
