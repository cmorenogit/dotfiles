#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-desktop}"
DOTFILES_PATH="${DOTFILES_PATH:-$HOME/.dotfiles}"

usage() {
  printf "Usage: %s [desktop|mini-cli]\n" "$0"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf "Missing command: %s\n" "$1" >&2
    exit 1
  }
}

install_homebrew_if_missing() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_brew_profile() {
  local shared="$DOTFILES_PATH/brew/Brewfile.shared"
  local profile_file

  case "$PROFILE" in
    desktop)
      profile_file="$DOTFILES_PATH/brew/Brewfile.desktop"
      ;;
    mini-cli)
      profile_file="$DOTFILES_PATH/brew/Brewfile.mini"
      ;;
    *)
      usage
      ;;
  esac

  brew bundle --file "$shared" --no-upgrade
  brew bundle --file "$profile_file" --no-upgrade
}

apply_dotly_symlinks() {
  local dotly_bin="$DOTFILES_PATH/modules/dotly/bin/dot"

  require_cmd git
  if [[ ! -x "$dotly_bin" ]]; then
    git -C "$DOTFILES_PATH" submodule update --init --recursive modules/dotly
  fi

  DOTFILES_PATH="$DOTFILES_PATH" DOTLY_PATH="$DOTFILES_PATH/modules/dotly" "$dotly_bin" self install
}

apply_profile_extras() {
  case "$PROFILE" in
    desktop)
      if [[ -x "$DOTFILES_PATH/scripts/macos-defaults-desktop.sh" ]]; then
        "$DOTFILES_PATH/scripts/macos-defaults-desktop.sh"
      fi
      ;;
    mini-cli)
      ;;
  esac
}

main() {
  install_homebrew_if_missing
  require_cmd brew
  install_brew_profile
  apply_dotly_symlinks
  apply_profile_extras

  printf "Bootstrap completed for profile: %s\n" "$PROFILE"
}

main "$@"
