#!/usr/bin/env bash
set -euo pipefail

# Export current macOS preferences to a timestamped snapshot.

DOTFILES_PATH="${DOTFILES_PATH:-$HOME/.dotfiles}"
OUT_DIR="${1:-$DOTFILES_PATH/backups/macos}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="$OUT_DIR/$STAMP"

mkdir -p "$SNAPSHOT_DIR"

DOMAINS=(
  "NSGlobalDomain"
  "com.apple.dock"
  "com.apple.finder"
  "com.apple.screencapture"
  "com.apple.trackpad"
  "com.apple.AppleMultitouchTrackpad"
  "com.apple.AppleMultitouchMouse"
  "com.apple.controlcenter"
  "com.apple.menuextra.clock"
  "com.apple.HIToolbox"
  "com.apple.symbolichotkeys"
)

for domain in "${DOMAINS[@]}"; do
  safe_name="${domain//./_}"
  output_file="$SNAPSHOT_DIR/${safe_name}.plist.txt"
  if defaults read "$domain" > "$output_file" 2>/dev/null; then
    :
  else
    printf "Domain unavailable: %s\n" "$domain" > "$output_file"
  fi
done

defaults -currentHost read -g > "$SNAPSHOT_DIR/currenthost_global.plist.txt" 2>/dev/null || true

{
  printf "snapshot_dir=%s\n" "$SNAPSHOT_DIR"
  printf "created_at=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf "host=%s\n" "$(hostname)"
  printf "macos=%s\n" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
} > "$SNAPSHOT_DIR/meta.env"

printf "macOS snapshot exported to %s\n" "$SNAPSHOT_DIR"
