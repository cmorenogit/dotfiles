export DOTFILES_PATH="/Users/cmoreno/.dotfiles"
export DOTLY_PATH="$DOTFILES_PATH/modules/dotly"
export DOTLY_THEME="codely"
export ZIM_HOME="$DOTFILES_PATH/shell/zsh/.zim"
export _EZA_PARAMS="--git --group-directories-first --time-style=long-iso --color-scale=all --icons"

# fnm: Node version manager (works in non-interactive shells, MCP servers, Git hooks)
# Use absolute path because .zshenv runs before PATH includes /opt/homebrew/bin
eval "$(/opt/homebrew/bin/fnm env)"
