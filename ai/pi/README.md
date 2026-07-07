# Pi config

Config mínima versionada para Pi.

## Qué vive acá

- `settings.json`: backup versionado de `~/.pi/agent/settings.json`.
- `skills/`: skills exclusivos o forks adaptados para Pi.

## Cómo se habilitan skills en Pi

- Skills compartidos con Claude: agregarlos explícitamente en `settings.json` → `skills[]`.
- Skills Pi-only/adaptados: guardarlos en `ai/pi/skills/<skill>/`.
- No usar `~/.agents/skills` por ahora: Pi lo auto-carga globalmente y rompería el control selectivo.

## Criterio para habilitar un skill Claude en Pi

Un skill Claude puede entrar en `settings.json` → `skills[]` solo si:

1. No depende de APIs, rutas o wording operativo específico de Claude:
   - `Task/Agent` o subagentes Claude-specific.
   - Modelos `Haiku` / `Opus` como requisito del flujo.
   - Rutas `~/.claude`.
   - Tools `mcp__*`.
2. Si usa herramientas externas (`gws`, `gh`, `unlighthouse`, etc.), debe declararlo explícitamente.
3. Si requiere cambios para Pi, NO se referencia desde `ai/claude/skills`; se crea fork en `ai/pi/skills/<skill>/`.
4. Si viene de un package npm, revisar si trae skills propios y filtrar con `skills: []` si no se quieren cargar.

## Estado actual

Skills Claude habilitados en Pi:

- `explica`
- `producto`

`~/.pi/agent/skills` apunta a este directorio para evitar cargar skills locales no versionados.
