---
name: solve-ticket
description: "Analiza, genera hipotesis y propone solucion para un ticket JIRA. Integra skills de debugging, arquitectura y code review automatico."
---

# solve-ticket

Orchestrates the full lifecycle of a JIRA ticket: intake → triage → investigate → fix → verify → deliver.
Tracks everything in bd (beads) with Engram for deep context persistence.

## Arguments

```
/solve-ticket PM-XXXX              # Full flow from JIRA ticket
/solve-ticket PM-XXXX --resume     # Resume from existing bd issue
/solve-ticket PM-XXXX --status     # Show current state of ticket investigation
```

## Execution Flow

### Phase 1: INTAKE

1. **Read JIRA ticket** via `atlassian_jira_get_issue` (PM-XXXX)
2. **Extract**: title, description, priority, reporter, comments, attachments
3. **Identify service(s)** affected from description/title (map to fuerza monorepo services)
4. **Create bd issue**:
   ```bash
   bd create "[servicio] PM-XXXX: {título corto}" -t bug -p {priority_map} --description "{resumen del ticket JIRA con contexto relevante}"
   ```
   Priority mapping: JIRA Highest/High → bd 1, Medium → 2, Low → 3
5. **Save to Engram** (initial context):
   ```
   mem_save(
     title: "ticket/PM-XXXX/intake",
     topic_key: "ticket/PM-XXXX/intake",
     type: "discovery",
     project: "fuerza",
     content: "# PM-XXXX: {title}\n\n## JIRA Context\n{description}\n\n## Service(s): {detected}\n## bd issue: {fuerza-xxx}\n## Priority: {p}\n## Reporter: {reporter}"
   )
   ```

### Phase 2: TRIAGE (automatic with override)

Analyze the ticket and **automatically decide** the route:

**Decision criteria:**

| Signal | 🟢 Simple | 🟡 Medium | 🔴 Complex |
|--------|-----------|-----------|------------|
| Services affected | 1 | 1-2 | 3+ |
| Likely root cause | Obvious from description | Needs investigation | Unknown/architectural |
| Scope of change | 1-2 files | 3-5 files | 6+ files or schema change |
| Cross-service comms | None | One direction | Bidirectional |
| Data migration needed | No | No | Yes |

**Output the triage decision:**
```
## Triage: PM-XXXX

**Ruta:** 🟡 Medio (investigación necesaria)
**Razón:** Afecta app-entrenamientos + incentivos, root cause no evidente
**Servicios:** app-entrenamientos, incentivos
**bd issue:** fuerza-xxx

Procedo con investigación. Si prefieres otra ruta, dime.
```

The user can override by saying "escálalo a SDD" or "es simple, arréglalo directo".

### Phase 3: INVESTIGATE

Based on triage route:

#### 🟢 Simple
- Read the relevant code directly
- Identify the fix
- Skip to Phase 4

#### 🟡 Medium
- Apply **systematic-debugging** skill methodology (Phase 1: Root Cause Investigation)
- Generate hypotheses and track in bd:
  ```bash
  bd update {id} --notes "H1: {hypothesis} → {CONFIRMED|DISCARDED|PENDING}"
  bd update {id} --notes "H2: {hypothesis} → {CONFIRMED|DISCARDED|PENDING}"
  bd update {id} --notes "Root cause: {description}"
  ```
- Save investigation to Engram:
  ```
  mem_save(
    title: "ticket/PM-XXXX/investigation",
    topic_key: "ticket/PM-XXXX/investigation",
    type: "bugfix",
    project: "fuerza",
    content: "# Investigation: PM-XXXX\n\n## Hypotheses\n{all hypotheses with status}\n\n## Root Cause\n{root cause}\n\n## Evidence\n{code refs, queries, logs}\n\n## Affected Files\n{file list with line numbers}"
  )
  ```

#### 🔴 Complex → Escalate to SDD
- Save investigation context to Engram (same as medium)
- Create SDD change linked to bd issue:
  ```bash
  bd update {id} --notes "ESCALATED to SDD: /sdd-new PM-XXXX-{short-name}"
  ```
- Inform user:
  ```
  Este ticket requiere SDD. Contexto guardado en:
  - bd: fuerza-xxx
  - Engram: ticket/PM-XXXX/investigation

  Siguiente paso: `/sdd-new PM-XXXX-{short-name}`
  El contexto de investigación se cargará automáticamente.
  ```
- **STOP here.** User decides when to run SDD.

### Phase 4: FIX

1. **Set bd status:**
   ```bash
   bd update {id} --status=in_progress
   ```

2. **Implement the fix:**
   - Follow existing code patterns and conventions
   - Respect Node.js 10 constraints (no ?., no ??)
   - cd to the correct subdirectory before any git operations
   - Protect .env and environment.ts files

3. **For medium fixes**, create child bd issues if multiple independent changes:
   ```bash
   bd create "[servicio-A] Fix query JOIN" -t task -p 1
   bd create "[servicio-B] Update validation" -t task -p 1
   bd dep add {child-id} {parent-id}
   ```

### Phase 5: VERIFY

Apply **verification-before-completion** skill:

1. Run the service locally if possible (`docker-compose up`, test endpoint)
2. Verify the fix addresses the root cause (not just symptoms)
3. Check for regressions in related functionality
4. Update bd with verification results:
   ```bash
   bd update {id} --notes "Verificación: {resultado}"
   ```

### Phase 6: DELIVER

1. **Commit** (in the correct subdirectory):
   ```bash
   cd {service-dir}
   git add {specific files}
   git commit -m "fix: {description} (PM-XXXX)"
   ```

2. **Generate PR description** using `docs/templates/TEMPLATE-PR-DESCRIPTION.md`

3. **Generate thread name** using `docs/templates/TEMPLATE-THREAD-NAMES.md`

4. **Generate chat message** using `docs/templates/TEMPLATE-CHAT-MESSAGES.md`

5. **Save final state to Engram:**
   ```
   mem_save(
     title: "ticket/PM-XXXX/resolution",
     topic_key: "ticket/PM-XXXX/resolution",
     type: "bugfix",
     project: "fuerza",
     content: "# Resolution: PM-XXXX\n\n## Root Cause\n{root cause}\n\n## Fix\n{what was changed and why}\n\n## Files Changed\n{list}\n\n## Verification\n{results}\n\n## bd issue: {fuerza-xxx}\n## PR: {branch name}\n## Commit: {hash}"
   )
   ```

6. **Close bd issue:**
   ```bash
   bd close {id} --reason="Fix: {one-line summary}. PR: {branch}"
   ```

7. **Present deliverables to user:**
   ```
   ## PM-XXXX: Resuelto ✓

   **Root cause:** {description}
   **Fix:** {what was done}

   ### Deliverables
   - PR description (listo para crear PR)
   - Hilo: {thread name}
   - Mensaje: {chat message}
   - bd: fuerza-xxx (closed)

   ### Destinatario PR
   {based on service type from CLAUDE.md rules}

   ¿Creo el PR?
   ```

## Engram Naming Convention

All ticket artifacts use deterministic naming for cross-session recovery:

| Artifact | topic_key | When |
|----------|-----------|------|
| Intake | `ticket/PM-XXXX/intake` | Phase 1 |
| Investigation | `ticket/PM-XXXX/investigation` | Phase 3 |
| Resolution | `ticket/PM-XXXX/resolution` | Phase 6 |

Recovery: `mem_search("ticket/PM-XXXX/")` → lists all artifacts for a ticket.

## SDD Escalation Protocol

When a ticket escalates to SDD:

1. The `ticket/PM-XXXX/investigation` Engram artifact becomes input for `sdd-explore`
2. The SDD change name follows: `PM-XXXX-{short-kebab-name}`
3. SDD artifacts use their own namespace: `sdd/PM-XXXX-{name}/{phase}`
4. The bd issue links both worlds:
   ```
   bd issue (fuerza-xxx)
     ├── notes: "ESCALATED to SDD"
     ├── notes: "SDD change: PM-XXXX-{name}"
     └── Engram refs: ticket/PM-XXXX/* + sdd/PM-XXXX-{name}/*
   ```

## --resume Flag

When called with `--resume`:
1. Search bd for existing issue matching PM-XXXX: `bd search "PM-XXXX"`
2. Recover Engram context: `mem_search("ticket/PM-XXXX/")`
3. Display current state and continue from where it left off

## --status Flag

When called with `--status`:
1. Show bd issue details: `bd show {id}`
2. Show Engram artifacts: `mem_search("ticket/PM-XXXX/")`
3. Present summary without executing any phase

## Rules

- ALWAYS create a bd issue before any investigation. No exceptions.
- ALWAYS save to Engram at each phase boundary (intake, investigation, resolution).
- NEVER skip triage. Even "obvious" fixes get triaged (they just route to 🟢 Simple).
- NEVER mix commits from different services in one commit.
- NEVER modify .env or environment.ts without explicit user confirmation.
- ALWAYS use the correct subdirectory for git operations.
- If JIRA ticket cannot be read (auth error, not found), ask user to paste the description manually and continue.
- If bd create fails, continue anyway but warn the user.
- Respect Node.js 10 syntax constraints in all code changes.
- Follow Conventional Commits format: `fix: description (PM-XXXX)`
