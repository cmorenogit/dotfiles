---
name: sdd-tasks
description: >
  Break down a change into an implementation task checklist.
  Trigger: When the orchestrator launches you to create or update the task breakdown for a change.
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for creating the TASK BREAKDOWN. You take the proposal, specs, and design, then produce a `tasks.md` with concrete, actionable implementation steps organized by phase.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `tasks`. Retrieve `proposal`, `spec`, and `design` as dependencies.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`.
- If mode is `none`: Return result only. Never create or modify project files.

## What to Do

### Step 1: Analyze the Design

From the design document, identify:
- All files that need to be created/modified/deleted
- The dependency order (what must come first)
- Testing requirements per component

### Step 2: Write tasks.md

Create the task file:

```
openspec/changes/{change-name}/
├── proposal.md
├── specs/
├── design.md
└── tasks.md               ← You create this
```

#### Task File Format

```markdown
# Tasks: {Change Title}

## Phase 1: {Phase Name} (e.g., Infrastructure / Foundation)

- [ ] 1.1 {Concrete action — what file, what change}
- [ ] 1.2 {Concrete action}
- [ ] 1.3 {Concrete action}

## Phase 2: {Phase Name} (e.g., Core Implementation)

- [ ] 2.1 {Concrete action}
- [ ] 2.2 {Concrete action}
- [ ] 2.3 {Concrete action}
- [ ] 2.4 {Concrete action}

## Phase 3: {Phase Name} (e.g., Testing / Verification)

- [ ] 3.1 {Write tests for ...}
- [ ] 3.2 {Write tests for ...}
- [ ] 3.3 {Verify integration between ...}

## Phase 4: {Phase Name} (e.g., Cleanup / Documentation)

- [ ] 4.1 {Update docs/comments}
- [ ] 4.2 {Remove temporary code}
```

### Task Writing Rules

Each task MUST be:

| Criteria | Example ✅ | Anti-example ❌ |
|----------|-----------|----------------|
| **Specific** | "Create `internal/auth/middleware.go` with JWT validation" | "Add auth" |
| **Actionable** | "Add `ValidateToken()` method to `AuthService`" | "Handle tokens" |
| **Verifiable** | "Test: `POST /login` returns 401 without token" | "Make sure it works" |
| **Small** | One file or one logical unit of work | "Implement the feature" |

### Phase Organization Guidelines

```
Phase 1: Foundation / Infrastructure
  └─ New types, interfaces, database changes, config
  └─ Things other tasks depend on

Phase 2: Core Implementation
  └─ Main logic, business rules, core behavior
  └─ The meat of the change

Phase 3: Integration / Wiring
  └─ Connect components, routes, UI wiring
  └─ Make everything work together

Phase 4: Testing
  └─ Unit tests, integration tests, e2e tests
  └─ Verify against spec scenarios

Phase 5: Cleanup (if needed)
  └─ Documentation, remove dead code, polish
```

### Testing Tasks — MANDATORY acceptance criteria

When generating tasks that produce tests, consume the Module Design "Test Pyramid & Structure ADR" (section 13 of the MDD) if it exists. If the MDD is absent or lacks the ADR, default to **60% unit / 30% service / 10% E2E** and auto-detect the pattern reference from the stack.

Every testing task MUST include these acceptance criteria inline:

| Criterion | Required content |
|-----------|------------------|
| **Tier** | Which pyramid tier: `unit/` / `service/` / `integration/` / `contracts/` / `security/` |
| **Directory** | Exact path under `__tests__/`, mirror of pattern reference |
| **DB requirement** | `fake (in-memory)` for unit tier, **`real Postgres (port 44321)` for service tier** (never fake at service tier) |
| **Pattern reference** | Name of the reference module + a specific test file to mirror (e.g., `challenge-api/__tests__/service/register-action.service.test.ts`) |
| **Cleanup** | `finally` block cleanup if tests create auth users (Luisa 2026-03-18 GoTrue-saturation standard) |
| **Anti-shortcut rules** | No timing-dependent assertions · no `setTimeout`/`sleep(ms)` waits · no interdependence between tests (each generates own `crypto.randomUUID()`) · specific assertions (exact error codes, not `.toBeTruthy()`) · one logical assertion per test |

Example task with full criteria:

```
- [ ] 4.2 Service test: approve/reject state machine
  Tier: service/
  Directory: supabase/functions/evidence-api/__tests__/service/approve-reject.service.test.ts
  DB: real Postgres (port 44321)
  Pattern reference: challenge-api/__tests__/service/register-action.service.test.ts
  Cleanup: auth users deleted in finally block
  Covers: R-004 (manager approves), R-005 (bulk reject), R-014 (idempotency on re-approve)
  Anti-shortcut: no fake-supabase; each test seeds its own tenant with crypto.randomUUID()
```

### Pyramid coverage per phase

When generating testing tasks, distribute by the ADR target:
- 60% of test tasks → `unit/` tier
- 30% of test tasks → `service/` tier — **this tier is not optional**
- 10% of test tasks → `integration/` or `e2e/`

If the generated task list has 0 service-tier tasks for a non-trivial module, that's a red flag — check the MDD's section 13 for the pattern reference and spread service tests accordingly.

### Step 3: Return Summary

Return to the orchestrator:

```markdown
## Tasks Created

**Change**: {change-name}
**Location**: openspec/changes/{change-name}/tasks.md

### Breakdown
| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | {N} | {Phase name} |
| Phase 2 | {N} | {Phase name} |
| Phase 3 | {N} | {Phase name} |
| Total | {N} | |

### Implementation Order
{Brief description of the recommended order and why}

### Next Step
Ready for implementation (sdd-apply).
```

## Rules

- ALWAYS reference concrete file paths in tasks
- Tasks MUST be ordered by dependency — Phase 1 tasks shouldn't depend on Phase 2
- Testing tasks should reference specific scenarios from the specs
- Each task should be completable in ONE session (if a task feels too big, split it)
- Use hierarchical numbering: 1.1, 1.2, 2.1, 2.2, etc.
- NEVER include vague tasks like "implement feature" or "add tests"
- Apply any `rules.tasks` from `openspec/config.yaml`
- If the project uses TDD, integrate test-first tasks: RED task (write failing test) → GREEN task (make it pass) → REFACTOR task (clean up)
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
