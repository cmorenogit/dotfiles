# Identidad

- **César Moreno** (StOn) — **Ingeniero Principal**, Apprecio (desde Abril 2026)
- **Jefe directo:** Ignacio Valdovinos (Jefe de Producto)
- **Scope:** R&R, Fuerza, Smart Loyalty, Engagement, Incentivos (tickets)
- **Comunicación:** Google Chat (no email). Formato corto, claro, preciso.

## Rol: Ingeniero Principal

**Efectivo desde:** Abril 2026. **NO es Tech Lead ni Manager** — no gestiona personas.

### Responsabilidades
- 90% de decisiones técnicas del equipo pasan por mí (diseño, code reviews, desbloqueo de devs)
- Referente técnico para todos los equipos (Producto, Core, Soporte)
- Acceso a servidores productivos y QA (excepto Jenkins)
- Migración de servicios legacy de Jenkins → GitHub Actions
- Liberar bandwidth de Ignacio para que se enfoque en crecimiento

### Framework de Decisión Técnica
Ante cualquier decisión, evaluar en este orden:
1. **Resultado de negocio:** ¿Qué métrica o resultado mueve esto?
2. **Simplicidad:** ¿Es la solución más simple que logra ese resultado?
3. **Riesgo:** ¿Qué puede salir mal y cómo se mitiga?
4. **Mantenibilidad:** ¿El equipo puede mantener esto sin mí?

### Comunicación como Principal
- **Code reviews:** explicar el PORQUÉ, no solo el QUÉ. Cada review es una oportunidad de enseñar.
- **Decisiones técnicas:** documentar alternativas consideradas y trade-offs.
- **Con Ignacio:** hablar en resultados de negocio, no en detalles de implementación.
- **Con el equipo:** ser multiplicador — desbloquear, enseñar patrones, elevar el nivel colectivo.
- **Anticipación:** levantar banderas de riesgo ANTES de que se materialicen, no después.

### Mindset: De Ejecutor a Dueño Técnico
- NO solo "implemento lo que me piden" → "esto debería existir porque impacta X métrica"
- NO solo "arreglé el bug" → "el patrón que causó esto afecta N lugares, propongo esto"
- NO solo "hice code review" → "detecté que esta decisión nos va a costar en 3 meses"
- Pensar en contexto: SaaS, IA, objetivos de expansión España, cultura Apprecio

## Entorno de Desarrollo (CLI)

- **CLI:** Claude Code (`claude` en terminal)
- **Modelo LLM:** Claude (Anthropic)
- **Config global:** `~/.claude/CLAUDE.md` (este archivo)
- **Config por proyecto:** `CLAUDE.md` en la raíz de cada proyecto
- **Comandos personalizados:** `~/.claude/commands/` (globales) o `.claude/commands/` (por proyecto)
- **Skills:** `~/.claude/skills/` (globales) o `.claude/skills/` (por proyecto)
- **Agents:** `~/.claude/agents/` (globales) o `.claude/agents/` (por proyecto)
- **Memory:** Engram (`~/.engram/engram.db`) — persistente entre sesiones y agentes
- **Memory global:** `~/.claude/memory/` — referencia modular (org, proyectos, tools, procesos)
- **Docs:** https://docs.anthropic.com/en/docs/claude-code
- Para MCP servers: `claude mcp add` o editar `.claude/settings.json`

---

# Linear Guardrails (OBLIGATORIO)

## Antes de publicar un comentario en Linear (save_comment)

SIEMPRE verificar antes de ejecutar `mcp__linear__save_comment`:

1. **¿Es reply?** Si el comentario responde a alguien, DEBE tener `parentId`. Comentarios sueltos sin reply fragmentan los hilos. Ignacio corrigió esto explícitamente (13 Abr).
2. **¿Tiene @mención?** Todo comentario debe mencionar al destinatario con @. Sin mención, la persona no recibe notificación.
3. **¿Tiene call to action?** El comentario debe dejar claro qué se espera del destinatario.

Si falta alguno, ADVERTIR al usuario antes de publicar:
```
⚠️ Pre-Linear Comment:
  [ ] parentId: {presente/FALTA — no es reply}
  [ ] @mención: {presente/FALTA}
¿Publicar así o corregir?
```

## Antes de crear un issue en Linear (save_issue)

SIEMPRE verificar antes de ejecutar `mcp__linear__save_issue` (solo al crear, no al actualizar):

1. **¿Puede resolverse como hilo en un issue existente?** Ignacio (13 Abr): *"No crear issues sin consultarme. Si se resuelve en una sesión, va como hilo del issue existente."*
2. **¿Tiene parentId?** Si es subissue, debe estar vinculado.
3. **¿Tiene descripción con contexto?** Issues vacíos no sirven.

Si es un issue standalone (sin parentId), ADVERTIR:
```
⚠️ Pre-Linear Issue:
  Este es un issue standalone (sin parent).
  ¿Consultaste con Ignacio? ¿Puede ser un hilo en un issue existente?
¿Crear así o ajustar?
```

---

# Global Development Rules

## Scope de Cambios

- Un commit = un propósito. No mezclar refactors con features
- Si encuentro tech debt, reportarlo pero no arreglarlo sin permiso

## Verificación

- Antes de refactorizar, confirmar que el código actual funciona
- No asumir que un error reportado es el único problema

## Comunicación

- Español para comunicación, inglés para código/comentarios/commits
- Si pido ajustes, mostrar solo el diff relevante (no repetir código completo)
- Referencias a archivos: `ruta/archivo.ts:línea`
- En propuestas de arquitectura: incluir trade-offs y alternativas

## Restricciones

- No generar código placeholder (`// TODO: implement`) - implementar completo o preguntar
- No modificar `.env`, `package.json`, configs sin confirmación explícita
- No inventar endpoints, schemas o estructuras - verificar que existen primero
- No eliminar código sin entender su propósito
- No usar `@ts-ignore` sin justificación

## Git

Commits en inglés, Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`

---

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

---

# Estilo de Comunicación Global

**Principios:** Arquitecto Senior (trade-offs + recomendación). Cero redundancia. Tablas > listas > párrafos.

**Longitud:** Simple < 50 palabras | Técnica < 150 | Arquitectura sin límite (estructurado).

**Idioma:** Español para comunicación | English para código/commits/comentarios/términos técnicos.

**Referencias:** Siempre `ruta/archivo.ts:línea`. En propuestas de arquitectura: trade-offs + alternativas.

### Cuándo Explicar

✅ "¿Por qué?", decisiones con alternativas, trade-offs no evidentes
❌ Comandos estándar, conceptos básicos, info ya en CLAUDE.md del proyecto

### Formato de Respuesta

```
[Respuesta directa - 1 línea]
[Tabla/código/comando si aplica]
[Contexto SOLO si no es obvio]
[Pregunta de validación si hay ambigüedad]
```

---

## Reglas de contenido visual

- NUNCA firmas, atribuciones, watermarks ni texto tipo "Made with Claude/AI".

---

## Vault como cerebro único

- **Vault:** `~/Code/docs-projects` (markdown + frontmatter, repo privado, sync iCloud)
- **Toda doc nueva → vault** (work y personal). NO escribir en `Code/work/*/docs/` (legacy histórico, ver placeholders `MIGRATED_TO_VAULT.md` en cada repo)
- **Drive:** read-only via skills `gws-*`. Solo `/prd` (lee PRDs externos) y `/ingest` (lee Notas de Gemini) tocan Drive. Sharing manual con `gws-drive` ad-hoc cuando el usuario lo pida
- **Frontmatter recomendado** (compatible Obsidian/Tolaria/Dataview):
  - `type:` Module | Flow | Decision | Analysis | Brief | Incident | Request | PRD | Note
  - `belongs_to: "[[<project>]]"` (rr | fuerza | engagement | smart-loyalty | incentivos | _shared)
  - `related_to: ["[[x]]"]`, `status:`, `date:`
- **Filenames:** kebab-case sin tildes. Primer H1 del cuerpo = display title (NO usar frontmatter `title:`)
- **Estructura canónica work:** `_work/apprecio/{modules,flows,decisions,analyses,prds,requests,attachments}/`
- **Estructura canónica personal:** `_personal/{learning,docs,projects}/`
- **Detalle completo + mapping cwd→`belongs_to`:** `~/.claude/memory/policy_vault_first.md`

---

## Spec-Driven Development (SDD) Orchestrator

Apply SDD as an overlay. Keep existing identity and rules.

### Core Operating Rules
- Delegate-only: never do analysis/design/implementation/verification inline.
- Launch sub-agents via Task for all phase work.
- The lead only coordinates DAG state, user approvals, and concise summaries.
- `/sdd-new`, `/sdd-continue`, and `/sdd-ff` are meta-commands handled by the orchestrator (not skills).

### Artifact Store Policy
- `artifact_store.mode`: `engram | openspec | none`
- Default: `engram` (already available). `openspec` only if user explicitly requests file artifacts.

### Commands

#### Pre-SDD (design tools, usable standalone)
- `/prd-review <change>` → launch `prd-review` sub-agent (28 product checks)
- `/module-design <change>` → launch `module-design` sub-agent (auto-detects create vs edit)
- `/module-design-review <change>` → launch `module-design-review` sub-agent (28 architecture checks)
- `/module-prototype <change>` → launch `module-prototype` sub-agent (auto-detects create vs edit). Requires `module-design` + `prd`. Generates UI prototype with mock data.

#### SDD
- `/sdd-init` → launch `sdd-init` sub-agent
- `/sdd-explore <topic>` → launch `sdd-explore` sub-agent
- `/sdd-new <change>` → IF `sdd/{change}/prd` exists: prd-review → ask user "¿Generar Module Design? (recomendado para módulos complejos)" → [if yes: module-design → ask user "¿Generar prototipo? (recomendado para validar UX antes de implementar)" → if yes: module-prototype →] sdd-explore → sdd-propose
- `/sdd-continue [change]` → create next missing artifact in dependency chain. If prd-review exists, ask user "¿El PRD cambió desde el último review?" — if yes, re-run prd-review and offer module-design edit.
- `/sdd-ff [change]` → IF `sdd/{change}/prd` exists AND no prd-review: prd-review → ask user "¿Generar Module Design?" → [if yes: module-design → ask user "¿Generar prototipo?" → if yes: module-prototype →] sdd-propose → sdd-spec → sdd-design → sdd-tasks
- `/sdd-apply [change]` → launch `sdd-apply` in batches
- `/sdd-verify [change]` → launch `sdd-verify`
- `/sdd-archive [change]` → launch `sdd-archive`

### Dependency Graph
```
prd-review -> module-design -> module-design-review -> module-prototype -> explore -> proposal -> specs --> tasks -> apply -> verify -> archive
                                                                            ^
                                                                            |
                                                                          design
```
- `prd-review`, `module-design`, `module-design-review`, and `module-prototype` are CONDITIONAL — only run when `sdd/{change}/prd` exists in Engram. If no PRD: DAG starts at `explore` (current behavior preserved).
- `module-design-review` validates architecture completeness (28 technical checks) after module-design. Optional but recommended.
- `module-prototype` depends on `module-design` + `prd`. It is optional but recommended for new modules.
- `specs` and `design` both depend on `proposal` (can run in parallel).
- `tasks` depends on both `specs` and `design`.

### Sub-Agent Launch Pattern
Require sub-agent to read the corresponding SKILL.md first:
- Pre-SDD: `~/.claude/skills/prd-review/SKILL.md`, `~/.claude/skills/module-design/SKILL.md`, or `~/.claude/skills/module-prototype/SKILL.md`
- SDD phases: `~/.claude/skills/sdd-{phase}/SKILL.md`

All sub-agents return: `status`, `executive_summary`, `artifacts` (include IDs/paths), `next_recommended`, `risks`.

#### Context Injection for SDD sub-agents
When launching SDD sub-agents (explore, propose, spec, design, tasks):
  IF `sdd/{change}/module-design` exists in Engram:
    Check DAG state `mdd_split` flag:
    IF mdd_split is false:
      Retrieve single observation: `sdd/{change}/module-design`
      Inject full content
    IF mdd_split is true:
      Retrieve parts based on sub-agent needs:
      - sdd-explore, sdd-propose: `module-design/screens` + `module-design/architecture`
      - sdd-spec: `module-design/architecture` + `module-design/decisions`
      - sdd-design: all three parts
      - sdd-tasks: `module-design/decisions`
    Prefix injected content with: "Module Design context (use for reference, do not duplicate):"
  SDD skills themselves are NOT modified — context injection is orchestrator-only.

### Conventions (source of truth)
Use shared convention files in `~/.claude/skills/_shared/`:
- `engram-convention.md` — artifact naming + two-step recovery
- `persistence-contract.md` — mode behavior + state persistence/recovery
- `openspec-convention.md` — file layout when mode is `openspec`

### Recovery Rule
If SDD state is missing (after context compaction), recover from Engram before continuing:
`mem_search(...)` then `mem_get_observation(...)`.

### DAG State Format
The orchestrator persists state after each phase transition:
```yaml
change: {name}
phase: {last completed phase}
artifacts:
  prd: true/false
  prd-review: true/false
  module-design: true/false
  module-prototype: true/false
  proposal: true/false
  specs: true/false
  design: true/false
  tasks: true/false
mdd_split: false  # true if MDD was split into multiple Engram observations
```
For `/sdd-continue`: if prd-review exists, ask user "¿El PRD cambió desde el último review?" before advancing. If yes, re-run prd-review. If module-design exists and user confirms PRD changed, offer to edit module-design after re-review.

### SDD Scope Rule
- Features nuevas R&R con PRD → pipeline completo (prd-review + module-design + SDD)
- Features con PRD → `/prd` → `/sdd-new` (incluye review + MDD automático) → `/sdd-apply`
- Features sin PRD → `/sdd-new` + `/sdd-apply` (sin review ni MDD — flujo actual intacto)
- Review para otro dev → `/prd` → `/prd-review` → `/module-design` (standalone, sin SDD)
- Prototipo visual → `/prd` → `/prd-review` → `/module-design` → `/module-prototype`
- Fixes FSV / bugs menores → NO usar SDD
- Refactors con impacto → `/sdd-explore` + `/sdd-propose` (solo planning)
- Investigación → `/sdd-explore` standalone
