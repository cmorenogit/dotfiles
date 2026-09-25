# Claude Code — Configuración local

> Este archivo complementa el AGENTS.md universal. Las políticas generales (cuándo persistir, qué no guardar, etc.) viven ahí; acá vive solo lo específico de Claude Code.

## Entorno
- Plugins activos: `engram` (memoria persistente) + `worktrunk` (worktrees)
- Claude Code carga los `@import` de `~/.claude/CLAUDE.md` **y** el auto-memory **por proyecto** `~/.claude/projects/<cwd-slug>/memory/MEMORY.md` (lo inyecta el harness solo, sin `@import`; el `MEMORY.md` es el índice y cada hecho vive en su propio `.md`). El dir global `~/.claude/memory/` es un stub histórico (migración 2026-05-04) y **no** se carga.

## Información organizacional de Apprecio
Roster de equipo, mapping de proyectos, configs de Linear y procesos detallados viven en el vault: `~/Code/_vault/_work/apprecio/_shared/`. Buscar ahí cuando se necesite contexto profundo de Apprecio que no esté en el AGENTS.md universal.

Lo crítico (resumen de equipo, mapping cwd→vault, regla wrappers multi-repo, flujo FSV resumido, setup Linear, reglas de Beads) ya vive en AGENTS.md universal.

---

## Engram — implementación en Claude Code

> **Desde 25-sep-2026: engram 2.2.0 + plugin 0.1.3.** El servidor MCP es el de usuario `engram` (herramientas `mcp__engram__*`; si no aparecen, cargarlas con ToolSearch), registrado por `engram setup claude-code`: el plugin ya no trae MCP propio, así que ese registro NO se borra. Protocolo de inicio en modo `slim`. El proyecto de Beat lo fija `ENGRAM_PROJECT=recognition-and-rewards` (settings.local.json de cada worktree). Las convenciones clave están fijadas (`mem_pin`) y aparecen primero en el contexto. Herramientas de admin (`mem_merge_projects`, `mem_pin`) no están en el perfil `agent`: se usan con `engram mcp --tools=all` por stdio. Rollback: `~/.engram/rollback-1.16.1/` + `engram.db.backup-pre-v2-*`.

Engram provee memoria persistente cross-session via skill `engram:memory` (always active) + tools MCP. Para el **principio y reglas generales** ver "Memoria persistente y aprendizajes" en AGENTS.md.

### Tools core (siempre disponibles, sin ToolSearch)
`mem_save`, `mem_search`, `mem_context`, `mem_session_summary`, `mem_get_observation`, `mem_save_prompt`, `mem_current_project`

### Tools deferidos (vía ToolSearch cuando se necesiten)
`mem_update`, `mem_suggest_topic_key`, `mem_session_start`, `mem_session_end`, `mem_stats`, `mem_delete`, `mem_timeline`, `mem_capture_passive`, `mem_merge_projects`

### Self-check después de cada task
"¿Hubo decisión, confirmación, preferencia, fix, aprendizaje o convención? Si sí → `mem_save` AHORA."

### Cuándo buscar (`mem_search`)
- Usuario pide recall ("acordate", "qué hicimos", "remember")
- Empezar trabajo que pudo haberse hecho antes
- Primer mensaje del usuario referenciando proyecto/feature/problema → buscar con keywords antes de responder

### Cierre de sesión (obligatorio antes de decir "listo")
Llamar `mem_session_summary` con un ÚNICO campo de texto `content` (más `project`), que es markdown con las secciones `## Goal`, `## Discoveries`, `## Accomplished`, `## Next Steps` y `## Relevant Files`. No existen parámetros `summary`/`goal`/`input`: pasarlos da "content is required" (falló en ~20 cierres de sesión, sep-2026). `mem_save` también exige `content` (más `title`, `type`, `project`).

### Conflict surfacing
Después de cada `mem_save`, revisar la respuesta. Si `judgment_required` es true:
- Iterar `candidates[]` y llamar `mem_judge` una vez por candidate (con su propio `judgment_id`).
- **Preguntar al usuario** si: confidence < 0.7, O si la relación es `supersedes`/`conflicts_with` y el tipo es architecture/policy/decision.
- **Resolver silenciosamente** si: confidence >= 0.7 AND la relación no es supersedes/conflicts_with, O la relación es `related`/`compatible`/`scoped`/`not_conflict`.
