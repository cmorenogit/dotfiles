# agents/ — config global agnóstica para CLIs de IA

Source of truth único para Claude Code, OpenCode y Pi. Cada CLI consume el contenido desde su path canónico vía symlink (XDG-first) o `@import` (Claude).

## Archivos

| Archivo | Audiencia | Activo en |
|---|---|---|
| `AGENTS.md` | Universal — los 3 CLIs | Claude (via @import), OpenCode, Pi |
| `CLAUDE.local.md` | Claude Code only (SDD orchestrator + engram + skills) | Claude (via @import) |
| `OPENCODE.local.md` | OpenCode only (engram protocol) | Versionado, inyección TBD |
| `PI.local.md` | Pi only (placeholder) | Versionado, inyección TBD |

## Setup en máquina nueva

Después de clonar dotfiles, crear los symlinks:

```bash
# Path canónico XDG (apunta al dir versionado)
ln -sfn ~/.dotfiles/agents ~/.config/agents

# OpenCode lee su AGENTS.md global
mkdir -p ~/.config/opencode
ln -sfn ~/.config/agents/AGENTS.md ~/.config/opencode/AGENTS.md

# Pi lee su AGENTS.md global
mkdir -p ~/.pi/agent
ln -sfn ~/.config/agents/AGENTS.md ~/.pi/agent/AGENTS.md

# Claude Code: archivo regular con imports (no symlink, ~/.claude/ no se versiona)
cat > ~/.claude/CLAUDE.md << 'EOF'
@~/.config/agents/AGENTS.md
@~/.config/agents/CLAUDE.local.md
EOF
```

## Diseño

- **XDG-first:** `~/.config/agents/` es el path canónico que aparece en imports y symlinks. Compatible con la propuesta del issue #91 de `agents.md` para auto-discovery futuro.
- **Source en dotfiles:** los `.md` viven en `~/.dotfiles/agents/`. `~/.config/agents` es symlink hacia ahí. Si se cambia el gestor de dotfiles (dotly → stow → yadm), solo se reapunta ese symlink — los CLIs no se enteran.
- **Solo Claude soporta `@import`.** OpenCode y Pi leen un solo archivo plano. Por eso los `.local.md` de OpenCode/Pi están versionados pero no se inyectan automáticamente. Mecanismo de inyección (concat o script) pendiente.
- **Engram fuera del universal:** requiere config manual por CLI (plugin en Claude, MCP en `opencode.json`). Vive duplicado en `CLAUDE.local.md` y `OPENCODE.local.md`.

## .gitignore

Los `.local.md` están exceptuados del patrón `**/*.local.*` (que dotly usa para machine-secrets). Ver `.gitignore` raíz: `!agents/*.local.md`.
