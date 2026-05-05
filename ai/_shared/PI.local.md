# Pi — Configuración local

> Este archivo complementa el AGENTS.md universal. Las políticas generales viven ahí; acá vive solo lo específico de Pi.

## Entorno
- Default provider en `~/.pi/agent/settings.json`: openrouter
- Engram configurado en `~/.pi/agent/mcp.json` (modo proxy-only, lazy)
- Pi tiene precedencia: system harness > project AGENTS.md > global AGENTS.md

## MCP en Pi (vía `pi-mcp-adapter`)

Pi CLI (`@mariozechner/pi-coding-agent`, dir `~/.pi/`) soporta MCP a través de la extensión **`pi-mcp-adapter`** (npm, repo `nicobailon/pi-mcp-adapter`).

### Instalación
```bash
pi install npm:pi-mcp-adapter
```
Agrega la entrada a `~/.pi/agent/settings.json` → `packages[]`.

### Paths de config soportados (precedencia descendente)

| Path | Scope |
|---|---|
| `~/.config/mcp/mcp.json` | global compartido (cross-host) |
| `~/.pi/agent/mcp.json` | global de Pi |
| `.mcp.json` | proyecto compartido |
| `.pi/mcp.json` | proyecto Pi |

`~/.config/agents/` NO está soportado por el adapter. La env var `$PI_CODING_AGENT_DIR` muda TODO el dir de pi (sessions, extensions, auth) — no usar para overridear solo MCP path.

**Default recomendado:** `~/.pi/agent/mcp.json` (mínima complejidad, dir nativo de Pi).

### Filosofía del adapter
Una sola tool proxy `mcp` (~200 tokens) en vez de exponer todas las tools de cada server (~10k tokens c/u). El agente descubre tools on-demand:
- `mcp({search: "..."})` para buscar
- `mcp({tool: "...", args: "..."})` para invocar

### Defaults a respetar

| Opción | Default | Cuándo cambiar |
|---|---|---|
| `lifecycle` | `lazy` (conecta al primer uso) | `keep-alive` solo si el server se usa todo el tiempo |
| `directTools` | omitido (proxy only) | `["tool_a", "tool_b"]` solo cuando sabés qué tools usa el modelo siempre |
| `settings.autoAuth` | `false` | `true` para que OAuth se dispare automático en primer tool call |

### Ejemplo — MCP HTTP con OAuth (Linear)
```json
{
  "settings": {
    "autoAuth": true
  },
  "mcpServers": {
    "linear": {
      "url": "https://mcp.linear.app/mcp",
      "auth": "oauth"
    }
  }
}
```

### Comandos útiles
- `/mcp` (dentro de Pi) — estado de servers, setup interactivo
- `pi-mcp-adapter init` (CLI) — escanea host configs (Cursor, Claude Code, Codex) y los importa

### Estado actual
- Adapter instalado en `~/.pi/agent/settings.json`
- `~/.pi/agent/mcp.json` con:
  - `linear` (HTTP, OAuth) — funcionando
  - `engram` (stdio, lazy, proxy-only) — invocación manual vía `mcp({tool:"mem_*", args:"..."})`

---

## Estado de inyección

Este archivo está versionado en `~/.dotfiles/agents/` pero **hoy NO se inyecta automáticamente** en Pi. Pi lee solo `~/.pi/agent/AGENTS.md` (symlink al universal).

Mecanismo de inyección a definir: concat `AGENTS.md + PI.local.md` → `~/.pi/agent/AGENTS.md`, o script de install.
