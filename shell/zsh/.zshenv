export DOTFILES_PATH="$HOME/.dotfiles"
export DOTLY_PATH="$DOTFILES_PATH/modules/dotly"
export DOTLY_THEME="codely"
export ZIM_HOME="$DOTFILES_PATH/shell/zsh/.zim"
export _EZA_PARAMS="--git --group-directories-first --time-style=long-iso --color-scale=all --icons"

# ~/.local/bin en shells NO interactivas (claude, herdr via ssh/cron)
export PATH="$HOME/.local/bin:$PATH"

# last30days: guardar research raw en el vault (no ~/Documents); robusto ante el --save-dir del flujo canónico de la skill
export LAST30DAYS_MEMORY_DIR="$HOME/Code/_vault/_personal/research/last30days"

# fnm: Node version manager (works in non-interactive shells, MCP servers, Git hooks)
# Use absolute path because .zshenv runs before PATH includes /opt/homebrew/bin
eval "$(/opt/homebrew/bin/fnm env)"

# API Keys (from secrets.sh, gitignored)
[ -f "$DOTFILES_PATH/shell/secrets.sh" ] && source "$DOTFILES_PATH/shell/secrets.sh"
