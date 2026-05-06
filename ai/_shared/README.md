# ai/_shared/ — config global agnóstica para CLIs de IA

Source of truth único para Claude Code, OpenCode y Pi. Cada CLI consume estos `.md` vía symlink (apuntando directo aquí) o `@import` (Claude vía path XDG).

## Archivos

| Archivo | Audiencia | Activo en |
|---|---|---|
| `AGENTS.md` | Universal — los 3 CLIs | Claude (via @import), OpenCode, Pi |
| `CLAUDE.local.md` | Claude Code only (SDD orchestrator + engram + skills) | Claude (via @import) |
| `OPENCODE.local.md` | OpenCode only (engram protocol) | Versionado, inyección TBD |
| `PI.local.md` | Pi only (placeholder) | Versionado, inyección TBD |

## Setup en máquina nueva

Los symlinks los crea dotly automáticamente al aplicar `~/.dotfiles/symlinks/conf.yaml`. No hay pasos manuales. Lo que se crea:

| Symlink | Apunta a |
|---|---|
| `~/.config/agents` (path canónico XDG) | `~/.dotfiles/ai/_shared` |
| `~/.config/opencode/AGENTS.md` | `~/.dotfiles/ai/_shared/AGENTS.md` |
| `~/.pi/agent/AGENTS.md` | `~/.dotfiles/ai/_shared/AGENTS.md` |
| `~/.claude/CLAUDE.md` | `~/.dotfiles/ai/claude/CLAUDE.md` (contiene los `@import`) |

## Diseño

- **Path canónico XDG para Claude:** `~/.config/agents/` aparece en los `@import` de `~/.claude/CLAUDE.md`. Compatible con la propuesta del issue #91 de `agents.md` para auto-discovery futuro.
- **OpenCode y Pi van directo:** sus `AGENTS.md` apuntan directamente a `ai/_shared/AGENTS.md` (un salto, sin pasar por XDG). Es más robusto a orden de creación y consistente con el patrón `editors/zed`, `terminal/tmux` del repo.
- **Solo Claude soporta `@import`.** OpenCode y Pi leen un solo archivo plano. Por eso los `.local.md` de OpenCode/Pi están versionados pero no se inyectan automáticamente. Mecanismo de inyección (concat o script) pendiente.
- **Engram fuera del universal:** requiere config manual por CLI (plugin en Claude, MCP en `opencode.json`). Vive duplicado en `CLAUDE.local.md` y `OPENCODE.local.md`.

## .gitignore

Los `.local.md` están exceptuados del patrón `**/*.local.*` (que dotly usa para machine-secrets). Ver `.gitignore` raíz: `!ai/_shared/*.local.md`.
