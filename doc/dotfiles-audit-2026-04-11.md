# Dotfiles Audit - 2026-04-11

## Goal

Restore the full desktop setup from dotfiles and use Mac mini as a CLI validation profile.

## Keep in dotfiles (source of truth)

- Shell: `shell/zsh/*`, `shell/aliases.sh`, `shell/functions.sh`, `shell/exports.sh`
- Git config: `shell/.gitconfig`
- Terminal: `terminal/tmux/*`, `terminal/sesh/*`, `terminal/lazygit/*`, `terminal/gh-dash/*`
- Ghostty config: `os/mac/ghostty/config`
- Tooling: `tooling/claude/*`, `tooling/opencode/*`
- Editor settings: `editors/zed/settings.json`

## Keep local only (never commit)

- SSH private keys: `~/.ssh/id_*`
- Claude credentials: `~/.claude/.credentials.json`
- GitHub token store: `~/.config/gh/hosts.yml`
- GCloud auth DBs: `~/.config/gcloud/credentials.db`, `~/.config/gcloud/access_tokens.db`
- Any `*.local` file and `*.db` runtime auth cache

## High-priority gaps found

1. `symlinks/conf.macos.yaml` did not include `ghostty`, `sesh`, and `zed` entries (now added).
2. Several Claude/OpenCode paths exist as real directories/files instead of symlinks, even when content matches dotfiles.
3. Raycast `~/.config/raycast/config.json` contains access tokens and must not be tracked directly.

## Credentials strategy

- Use Bitwarden CLI (`bw`) as secure source.
- Keep templates in repo, secrets out of git.
- Populate local secrets with `scripts/secrets-bootstrap.sh`.

## Safe sequence

1. Backup current local state (`~/.claude`, `~/.config/opencode`, `~/.ssh`, `~/.config/gh`).
2. Apply symlinks from dotfiles.
3. Run `scripts/secrets-bootstrap.sh` with Bitwarden item IDs.
4. Validate tools (`claude`, `opencode`, `gh`, `tmux`, `sesh`, `git`).
