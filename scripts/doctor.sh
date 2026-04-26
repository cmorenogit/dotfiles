#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-desktop}"
DOTFILES_PATH="${DOTFILES_PATH:-$HOME/.dotfiles}"

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1"; exit 1; }

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command available: $cmd"
  else
    warn "command missing: $cmd"
  fi
}

check_link() {
  local target="$1"
  local source="$2"
  if [[ ! -L "$target" ]]; then
    warn "not symlink: $target"
    return
  fi

  local current
  current="$(readlink "$target")"
  if [[ "$current" == "$source" ]]; then
    ok "symlink: $target -> $source"
  else
    warn "symlink target mismatch: $target -> $current (expected $source)"
  fi
}

if [[ ! -d "$DOTFILES_PATH" ]]; then
  fail "dotfiles path not found: $DOTFILES_PATH"
fi

check_cmd git
check_cmd brew
check_cmd zsh
check_cmd tmux
check_cmd sesh
check_cmd nvim
check_cmd gh
check_cmd bw

check_link "$HOME/.zshrc" "$DOTFILES_PATH/shell/zsh/.zshrc"
check_link "$HOME/.zshenv" "$DOTFILES_PATH/shell/zsh/.zshenv"
check_link "$HOME/.gitconfig" "$DOTFILES_PATH/shell/.gitconfig"
check_link "$HOME/.tmux.conf" "$DOTFILES_PATH/terminal/tmux/.tmux.conf"
check_link "$HOME/.claude/settings.json" "$DOTFILES_PATH/tooling/claude/settings.json"
check_link "$HOME/.config/opencode/opencode.json" "$DOTFILES_PATH/tooling/opencode/opencode.json"

if [[ "$PROFILE" == "desktop" ]]; then
  check_link "$HOME/.config/ghostty/config" "$DOTFILES_PATH/os/mac/ghostty/config"
  check_link "$HOME/.config/sesh" "$DOTFILES_PATH/terminal/sesh"
  check_link "$HOME/.config/zed/settings.json" "$DOTFILES_PATH/editors/zed/settings.json"
else
  ok "profile mini-cli: desktop UI checks skipped"
fi

if grep -q "/Users/cmoreno/.dotfiles" "$DOTFILES_PATH/shell/zsh/.zshenv"; then
  warn "hardcoded path found in shell/zsh/.zshenv"
else
  ok "portable path in shell/zsh/.zshenv"
fi

ok "doctor completed"
