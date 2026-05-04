# Pi — Configuración local

(Reservado — sin contenido Pi-específico por ahora)

## Notas para futuro

- Pi tiene precedencia documentada: system harness > project AGENTS.md > global AGENTS.md
- Default provider en `~/.pi/agent/settings.json`: openrouter
- Engram NO está configurado en Pi (a diferencia de Claude y OpenCode)
- Si aparece contenido Pi-específico, definir mecanismo de inyección (concat o append) — Pi no soporta `@import`

## Estado actual de inyección

Este archivo está versionado en `~/.dotfiles/agents/` pero **hoy NO se inyecta automáticamente** en Pi. Pi lee solo `~/.pi/agent/AGENTS.md` (symlink al universal).
