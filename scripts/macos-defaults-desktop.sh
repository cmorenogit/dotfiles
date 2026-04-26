#!/usr/bin/env bash
set -euo pipefail

# Applies a curated subset of desktop macOS defaults.

DOTFILES_PATH="${DOTFILES_PATH:-$HOME/.dotfiles}"

mkdir -p "$HOME/Downloads/screenshot"

# Global behavior
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock show-recents -bool false

# Finder
defaults write com.apple.finder ShowStatusBar -bool false

# Screenshots
defaults write com.apple.screencapture location -string "$HOME/Downloads/screenshot"

# Trackpad (common non-host-specific keys)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadPinch -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadScroll -bool true

killall Dock >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

# Optional user-specific overrides (not tracked)
if [[ -f "$DOTFILES_PATH/scripts/macos-defaults-user.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$DOTFILES_PATH/scripts/macos-defaults-user.local.sh"
fi

printf "Applied desktop macOS defaults.\n"
