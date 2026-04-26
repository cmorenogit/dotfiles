#!/usr/bin/env bash
set -euo pipefail

# Bootstrap local secrets from Bitwarden CLI.
# This script never writes secrets to tracked files.

DOTFILES_PATH="${DOTFILES_PATH:-$HOME/.dotfiles}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf "Missing command: %s\n" "$1" >&2
    exit 1
  }
}

ensure_bw_session() {
  local status
  status="$(bw status 2>/dev/null | jq -r '.status // "unknown"')"

  if [[ "$status" == "unauthenticated" ]]; then
    printf "Bitwarden CLI is not logged in. Run: bw login\n" >&2
    exit 1
  fi

  if [[ -z "${BW_SESSION:-}" ]]; then
    if [[ "$status" == "locked" ]]; then
      printf "Bitwarden vault is locked. Run: export BW_SESSION=\"\$(bw unlock --raw)\"\n" >&2
      exit 1
    fi
  fi
}

bw_get_notes() {
  local item="$1"
  if [[ -n "${BW_SESSION:-}" ]]; then
    bw get notes "$item" --session "$BW_SESSION"
  else
    bw get notes "$item"
  fi
}

bw_get_password() {
  local item="$1"
  if [[ -n "${BW_SESSION:-}" ]]; then
    bw get password "$item" --session "$BW_SESSION"
  else
    bw get password "$item"
  fi
}

write_private_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  chmod 600 "$path"
}

require_cmd bw
require_cmd jq

ensure_bw_session

# 1) shell/secrets.sh from secure note (optional)
if [[ -n "${BW_ITEM_SHELL_SECRETS:-}" ]]; then
  bw_get_notes "$BW_ITEM_SHELL_SECRETS" | write_private_file "$DOTFILES_PATH/shell/secrets.sh"
  printf "Updated %s\n" "$DOTFILES_PATH/shell/secrets.sh"
fi

# 2) SSH private key from secure note (optional)
if [[ -n "${BW_ITEM_SSH_KEY:-}" ]]; then
  bw_get_notes "$BW_ITEM_SSH_KEY" | write_private_file "$HOME/.ssh/id_ed25519"
  if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    chmod 644 "$HOME/.ssh/id_ed25519.pub"
  fi
  printf "Updated %s\n" "$HOME/.ssh/id_ed25519"
fi

# 3) GitHub CLI auth from token item (optional)
if [[ -n "${BW_ITEM_GH_TOKEN:-}" ]]; then
  require_cmd gh
  bw_get_password "$BW_ITEM_GH_TOKEN" | gh auth login --hostname github.com --with-token
  printf "Refreshed GitHub CLI auth via token\n"
fi

printf "Secrets bootstrap completed.\n"
