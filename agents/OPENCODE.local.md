# OpenCode — Configuración local

## Engram en OpenCode

Engram está disponible como MCP server local declarado en `~/.config/opencode/opencode.json`:

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

### Protocolo de uso de engram

(Mismo protocolo que en Claude Code — duplicado intencional hasta definir mecanismo de inyección compartido).

#### Cuándo guardar (mem_save proactivo)
- Decisión tomada (arquitectura, convención, workflow, tool choice)
- Bug arreglado (incluir root cause)
- Convención/workflow documentado o actualizado
- Descubrimiento no obvio, gotcha, edge case
- Patrón establecido (naming, estructura, approach)
- Preferencia/restricción del usuario aprendida
- Usuario confirma o rechaza un approach

**Self-check después de cada task:** "¿Hubo decisión, confirmación, preferencia, fix, aprendizaje o convención? Si sí → mem_save AHORA."

#### Cuándo buscar (mem_search)
- Usuario pide recall ("acordate", "qué hicimos")
- Empezar trabajo que pudo haberse hecho antes
- Primer mensaje referenciando proyecto/feature/problema

#### Cierre de sesión
Antes de decir "listo": llamar `mem_session_summary` con Goal, Discoveries, Accomplished, Next Steps, Relevant Files.

#### Qué NO guardar
- Patrones derivables del código actual
- Git history (`git log` es la fuente)
- Detalles efímeros de tarea en curso
- Cosas ya documentadas en AGENTS.md

---

## Estado actual de inyección

**Importante:** este archivo está versionado en `~/.dotfiles/agents/` pero **hoy NO se inyecta automáticamente** en OpenCode. OpenCode lee solo `~/.config/opencode/AGENTS.md` (symlink al universal) y `opencode.json`.

**Mecanismo de inyección a definir:** concat `AGENTS.md + OPENCODE.local.md` → `~/.config/opencode/AGENTS.md` (sobreescribe symlink) o script de install.

Hasta que se active: el contenido de este archivo es referencia/source para futuro.
