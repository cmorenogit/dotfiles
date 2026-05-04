# Claude Code — Configuración local

## Entorno

- Claude Code CLI con plugins `engram` (memory persistente) + `worktrunk` (worktrees)
- Memory global modular en `~/.claude/memory/` (índice: `MEMORY.md`)
- Detalle + mapping cwd→`project` para vault: `~/.claude/memory/policy_vault_first.md`

---

## Engram — Memoria Persistente (protocolo de uso)

Engram provee memoria que sobrevive entre sesiones y compactaciones. En Claude Code está disponible vía skill `engram:memory` (always active) + tools MCP.

### Tools core (siempre disponibles, sin ToolSearch)
`mem_save`, `mem_search`, `mem_context`, `mem_session_summary`, `mem_get_observation`, `mem_save_prompt`, `mem_current_project`

### Tools deferidos (vía ToolSearch cuando se necesiten)
`mem_update`, `mem_suggest_topic_key`, `mem_session_start`, `mem_session_end`, `mem_stats`, `mem_delete`, `mem_timeline`, `mem_capture_passive`, `mem_merge_projects`

### Cuándo guardar (mem_save proactivo, no esperar a que pidan)
- Decisión tomada (arquitectura, convención, workflow, tool choice)
- Bug arreglado (incluir root cause)
- Convención/workflow documentado o actualizado
- Notion/Jira/Linear/GitHub artefacto creado con contenido significativo
- Descubrimiento no obvio, gotcha, edge case
- Patrón establecido (naming, estructura, approach)
- Preferencia/restricción del usuario aprendida
- Feature implementada con approach no obvio
- Usuario confirma recomendación ("dale", "go with that", "sí esa")
- Usuario rechaza approach o expresa preferencia

**Self-check después de cada task:** "¿Hubo decisión, confirmación, preferencia, fix, aprendizaje o convención? Si sí → mem_save AHORA."

### Cuándo buscar (mem_search)
- Usuario pide recall ("acordate", "qué hicimos", "remember")
- Empezar trabajo que pudo haberse hecho antes
- Usuario menciona tema sin contexto previo
- PRIMER mensaje del usuario referenciando proyecto/feature/problema → buscar con keywords antes de responder

### Cierre de sesión (obligatorio antes de decir "listo"/"done")
Llamar `mem_session_summary` con: Goal, Discoveries, Accomplished, Next Steps, Relevant Files.

### Conflict surfacing
Después de cada `mem_save`, revisar la respuesta. Si `judgment_required` es true:
- Iterar `candidates[]` y llamar `mem_judge` una vez por candidate (con su propio `judgment_id`).
- **Preguntar al usuario** si: confidence < 0.7, O si la relación es `supersedes`/`conflicts_with` y el tipo es architecture/policy/decision.
- **Resolver silenciosamente** si: confidence >= 0.7 AND la relación no es supersedes/conflicts_with, O la relación es `related`/`compatible`/`scoped`/`not_conflict`.

### Qué NO guardar
- Patrones/convenciones/arquitectura derivables del código actual
- Git history o quién cambió qué (`git log` es la fuente)
- Soluciones de debugging (la fix está en el código + commit message)
- Cosas ya documentadas en AGENTS.md o CLAUDE.md
- Detalles efímeros de tarea en curso

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
- Features nuevas con PRD → pipeline completo (prd-review + module-design + SDD)
- Features con PRD → `/prd` → `/sdd-new` (incluye review + MDD automático) → `/sdd-apply`
- Features sin PRD → `/sdd-new` + `/sdd-apply` (sin review ni MDD — flujo actual intacto)
- Review para otro dev → `/prd` → `/prd-review` → `/module-design` (standalone, sin SDD)
- Prototipo visual → `/prd` → `/prd-review` → `/module-design` → `/module-prototype`
- Fixes FSV / bugs menores → NO usar SDD
- Refactors con impacto → `/sdd-explore` + `/sdd-propose` (solo planning)
- Investigación → `/sdd-explore` standalone
