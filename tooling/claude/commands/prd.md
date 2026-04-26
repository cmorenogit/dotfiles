---
description: Generate a complete PRD from Google Drive docs for SDD workflow
---

# PRD Generator from Drive Documentation

Generate a structured Product Requirements Document by reading existing documentation from Google Drive. The PRD is saved to Engram with SDD-compatible naming for direct consumption by `/sdd-new`.

## Modes

| Mode | Command | What it does |
|------|---------|-------------|
| **Create** | `/prd <name>` | Generates PRD from Drive docs → saves to Engram |
| **Update** | `/prd <name> --update` | Re-reads Drive docs, merges changes into existing PRD |
| **Edit** | `/prd <name> --edit` | Shows current PRD, you say what to change |

### Additional flags
- `--folder <drive-folder>`: Search in specific Drive folder
- `--docs <doc1,doc2,...>`: Read specific Google Doc names (comma-separated)
- `--file <path>`: Read PRD from a local file instead of Google Drive

## Mode: Create (default)

### PHASE 1: Gather Documentation

1. **If `--docs` provided:** Read those specific Google Docs via gws-docs
2. **If `--folder` provided:** List files in that Drive folder via gws-drive, then read relevant docs
3. **If `--file` provided:** Read the local file at the given path. Extract the same information as from Drive docs (business context, rules, flows, metrics, roles, edge cases, constraints).
4. **If none of the above:** Search Drive for docs matching `<change-name>` keywords (e.g., "challenges", "scorecard", "worklife"). Show results and ask user which to include.

For each doc found, read its FULL content via gws-docs. Extract:
- Business context and objectives
- Current rules and flows
- Metrics and KPIs
- User roles and permissions
- Edge cases and constraints

### PHASE 2: Clarifying Questions

Before generating, ask the user (max 4-5 questions):

1. **Scope:** "Based on the docs, I found these areas: [list]. Which are IN scope for this change?"
2. **Out of scope:** "Should I explicitly exclude anything?"
3. **Stakeholder validation:** "Has anyone from product (Nicole, Ignacio) confirmed this scope? Who should approve before we proceed?"
4. **Priority:** "What's the most important user outcome?"
5. **Edge cases:** "Are there error scenarios or edge cases I should consider? (e.g., offline, permissions denied, duplicate data, storage full)"
6. **Scope validation:** "The docs mention these features: [list]. Has the stakeholder confirmed ALL of these are in scope for this phase? Or should I cut some?"

Skip questions if the docs already provide clear answers.

### PHASE 3: Generate PRD

Structure the PRD using this template:

```markdown
# PRD: {Change Title}

## Problem Statement
{What pain point does this solve? For whom? Include business context from docs.}

## Objectives
{Measurable outcomes. Use KPIs from scorecard if available.}
- Objective 1: {metric}
- Objective 2: {metric}

## Scope

### Included
- {Feature/capability 1}
- {Feature/capability 2}

### Out of Scope
- {Explicitly deferred items}

## User Stories

### US-001: {Title}
**As a** {role from docs} **I want** {action} **so that** {benefit}

**Acceptance Criteria:**
- GIVEN {precondition from docs}
  WHEN {user action}
  THEN {expected outcome}
- GIVEN {precondition}
  WHEN {action}
  THEN {outcome}

### US-002: {Title}
...

## Functional Requirements

### FR-01: {Requirement Name}
The system MUST {behavior}. {Context from docs.}

### FR-02: {Requirement Name}
The system SHOULD {behavior}.

## Non-Functional Requirements
- **Performance:** {user-facing expectation, e.g., "flow completes in <60 seconds" — NOT P95 latency or technical metrics}
- **Security:** {data isolated per organization, access controlled by role — NOT RLS policies or auth implementation}
- **Compatibility:** {browser support, mobile, etc.}

## Risks and Dependencies

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| {Risk from docs} | Low/Med/High | Low/Med/High | {Plan} |

## Dependencies
- {External service or team dependency}
- {Data migration or schema changes}

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| {from docs or "TBD — resolve in PRD Review"} | {behavior} |
| {error scenario} | {graceful handling} |

## Product Decisions

| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| {product decision from docs — NOT technical/architecture decisions} | {what was discarded} | {why} |

## Deployment Risk

{Describe the deployment risk in product terms — NOT implementation details:}
- **Activation:** {How will users access this? Gradual rollout? All at once?}
- **Deactivation:** {Can it be turned off without losing user data? What's the impact?}
- **Data risk:** {Does this change existing data or only create new data?}

## Business Rules & Constraints

| Rule | Description | Justification |
|------|-------------|---------------|
| {business rule from docs — express as WHAT, not HOW} | {description} | {why this rule exists} |

## Business Model Connection

{How does this module create value for the business? What's the revenue/engagement impact?}

## Phasing

### Phase 1 (current scope)
{What's included and WHY it's the right starting point}

### Phase 2+ (deferred)
{What's deferred and WHY — not just a list, but the reasoning for deferring}

## Assumptions

| Assumption | Impact if Wrong |
|------------|-----------------|
| {what we assume is true} | {what breaks if this assumption fails} |

## Stakeholder Approval

- **Product:** {who validated the scope — name or "pending"}
- **Priority:** {who confirmed the priority — name or "pending"}

## Success Criteria
- [ ] All user stories implemented and tested
- [ ] {Business metric from objectives}
- [ ] Stakeholder sign-off received

## Source Documents
{List of Google Drive docs used to generate this PRD with links}
```

### PHASE 4: Save to Engram

Save the PRD with SDD-compatible naming:

```
mem_save(
  title: "sdd/{change-name}/prd",
  topic_key: "sdd/{change-name}/prd",
  type: "architecture",
  project: {detected project name},
  content: {full PRD markdown}
)
```

### PHASE 4.5: Save versioned copy to Tolaria vault

Save a **versioned, human-readable copy** to the vault for evolution tracking. Engram is the cache; vault is the canonical history.

**Path:** `_work/apprecio/prds/{change-name}-v{N}.md`

Where `N` is determined by:
1. List existing files matching `_work/apprecio/prds/{change-name}-v*.md`
2. If none → `N = 1`
3. If present → `N = max(existing) + 1`

**File content** = full PRD markdown body, with this Tolaria frontmatter prepended:

```yaml
---
type: PRD
status: Draft
project: <slug>                              # rr | fuerza | engagement | smart-loyalty | incentivos
related_to:                                  # opcional, módulos afectados
  - "[[<module-1>]]"
  - "[[<module-2>]]"
version: {N}
change_name: {change-name}
date: YYYY-MM-DD
source_drive_docs:                           # IDs de docs Drive usados (si aplica)
  - "<doc-id-1>"
  - "<doc-id-2>"
engram_topic: "sdd/{change-name}/prd"        # back-link al cache Engram
---
```

**Mode-specific behavior:**

| Mode | Path action |
|------|-------------|
| `--create` | Always creates `v{N}` (next number) |
| `--update` | Creates new `v{N+1}` (preserves history). Old versions remain. |
| `--edit` | Creates new `v{N+1}` (every edit is a version). Old versions remain. |

If `_work/apprecio/prds/` doesn't exist, create it.

### PHASE 5: Confirm and Next Steps

Show the user:
```
PRD generated and saved (Engram cache + vault canonical).
- Topic key: sdd/{change-name}/prd
- Vault: _work/apprecio/prds/{change-name}-v{N}.md
- User stories: {count}
- Requirements: {count}
- Source docs: {count}

Next steps:
  /prd-review {change-name}  ← validate PRD completeness (recommended)
  /module-design {change-name} ← generate architecture + wireframes (for complex modules)
  /sdd-new {change-name}     ← prd-review + module-design + exploration + proposal
  /sdd-ff {change-name}      ← fast-forward all planning phases
```

## Mode: Update (`--update`)

Re-reads Drive documentation and merges changes into the existing PRD.

### FLOW

1. **Retrieve current PRD** from Engram:
   - `mem_search(query: "sdd/{change-name}/prd")` → get observation ID
   - `mem_get_observation(id)` → full PRD content

2. **Re-read Drive docs** (same sources listed in "Source Documents" section of current PRD)

3. **Diff analysis** — Compare current PRD against updated docs:
   - New information not in current PRD
   - Changed requirements or flows
   - Removed or deprecated items

4. **Show diff to user:**
   ```
   PRD Update for {change-name}:

   NEW (from updated docs):
   - {new requirement or context}

   CHANGED:
   - FR-02: was "{old}", now "{new}" (source: {doc name})

   POTENTIALLY REMOVED:
   - {item no longer in docs — confirm with user}
   ```

5. **Ask user:** "Which changes should I incorporate?"

6. **Merge approved changes** into the PRD and save to Engram (same topic_key = upsert)

7. **Show summary:** what changed, new counts, next steps

## Mode: Edit (`--edit`)

Manual editing of an existing PRD without re-reading Drive.

### FLOW

1. **Retrieve current PRD** from Engram (same 2-step as Update mode)

2. **Show current PRD** to user (full content)

3. **Wait for instructions.** User says what to change:
   - "Add a user story for bulk export"
   - "Change FR-03 to SHOULD instead of MUST"
   - "Remove the mobile compatibility requirement"
   - "Update the risk table with a new dependency"

4. **Apply changes** to the PRD

5. **Show diff** of what changed (before/after for modified sections)

6. **Save to Engram** (same topic_key = upsert)

7. **Confirm:** "PRD updated. {N} sections modified."

## Rules

- ALWAYS read real docs from Drive/file — never invent content
- ALWAYS use RFC 2119 keywords (MUST, SHALL, SHOULD, MAY) in requirements
- ALWAYS write Acceptance Criteria in GIVEN/WHEN/THEN format (not just checkboxes)
- ALWAYS save to Engram with `sdd/{change-name}/prd` topic_key
- ALWAYS include Business Model Connection — how the module creates value
- ALWAYS include Phasing section with reasoning for phase boundaries
- ALWAYS include Assumptions section — flag unknowns rather than guessing
- ALWAYS include Stakeholder Approval — who validated this scope
- ALWAYS include Deployment Risk with product-level risk assessment (NOT technical migration details)
- ALWAYS include Edge Cases section — extract from docs, mark "TBD" if not found, NEVER omit
- ALWAYS include Product Decisions for non-trivial PRODUCT decisions found in source docs
- NEVER skip the clarifying questions phase — even 1 question helps
- NEVER include implementation details — PRD describes WHAT, not HOW
- NEVER mention database schemas, RLS policies, Zod schemas, HTTP status codes, idempotency keys, specific technologies, or infrastructure in the PRD. These belong in Module Design.
- Keep user stories small — each should be independently implementable
- Max 4 Acceptance Criteria per User Story. If a US needs more, split it into two stories. Technical ACs (idempotency, concurrency, error codes) belong in sdd-spec, not the PRD.
- Business Rules must express WHAT ("prevent abuse", "limit spending"), not HOW ("5 req/min with Redis counter", "CHECK constraint in DB")
- Product Decisions are about PRODUCT choices ("instant rewards over scheduled"), not ARCHITECTURE choices ("signed URLs over public buckets")
- Edge Cases must be USER-FACING scenarios ("user sees error message"), not SYSTEM-INTERNAL ("DB constraint prevents duplicate")
- Reference source docs at the end for traceability
- If a doc is too vague, flag it as "TBD" in the PRD rather than guessing

### Examples: Good vs Bad (for calibration)

**Acceptance Criteria:**
- GOOD: GIVEN the user sent 5 appreciations today WHEN they try to send another THEN they see "Daily limit reached, try again tomorrow"
- BAD: GIVEN rate_limit_counter >= 5 WHEN POST /rewards returns 429 THEN client shows toast (too technical, mentions HTTP code and implementation)

**Business Rules:**
- GOOD: "Users have a limited monthly budget for peer recognitions to prevent abuse"
- BAD: "50 pts/month per user, stored in peer_allowances table, reset via cron job day 1" (implementation detail)

**Product Decisions:**
- GOOD: "Peer recognitions are always public because visibility drives cultural modeling"
- BAD: "Use Supabase Realtime for feed updates with RLS filtering" (architecture, not product)

**Edge Cases:**
- GOOD: "User tries to recognize themselves → system shows 'You cannot recognize yourself'"
- BAD: "CHECK constraint giver_id ≠ recipient_id prevents self-reward" (DB implementation)
