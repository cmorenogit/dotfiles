# OpenCode — Configuración local

> Este archivo complementa el AGENTS.md universal. Las políticas generales (cuándo persistir, qué no guardar, etc.) viven ahí; acá vive solo lo específico de OpenCode.

## Engram — implementación en OpenCode

Engram disponible como MCP server local declarado en `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "engram": {
      "command": ["/opt/homebrew/Cellar/engram/<version>/bin/engram", "mcp", "--tools=agent"],
      "enabled": true,
      "type": "local"
    }
  }
}
```

Tools accesibles vía prefijo MCP estándar de OpenCode.

### Self-check después de cada task
"¿Hubo decisión, confirmación, preferencia, fix, aprendizaje o convención? Si sí → `mem_save` AHORA."

### Cuándo buscar (`mem_search`)
- Usuario pide recall ("acordate", "qué hicimos")
- Empezar trabajo que pudo haberse hecho antes
- Primer mensaje referenciando proyecto/feature/problema

### Cierre de sesión
Antes de decir "listo": llamar `mem_session_summary` con Goal, Discoveries, Accomplished, Next Steps, Relevant Files.

---

## Estado actual de inyección

Este archivo está versionado en `~/.dotfiles/agents/` pero **hoy NO se inyecta automáticamente** en OpenCode. OpenCode lee solo `~/.config/opencode/AGENTS.md` (symlink al universal) y `opencode.json`.

Mecanismo de inyección a definir: concat `AGENTS.md + OPENCODE.local.md` → `~/.config/opencode/AGENTS.md`, o script de install.
