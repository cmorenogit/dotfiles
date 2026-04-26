---
name: module-spec-kit
description: Use when creating the business specification (Constitution + Clarifications) for an R&R module before implementation begins.
---

# Module Spec-Kit

## Overview

Create the authoritative business specification for an R&R module using the spec-driven
development methodology proven with WorkLife. Produces two documents that serve as the
single source of truth for all implementation decisions.

**Announce at start:** "I'm using the module-spec-kit skill to create the specification for <MODULE>."

## When to Use

- Before starting implementation of ANY module
- When business rules are ambiguous or undocumented
- When multiple stakeholders have conflicting requirements
- When retrofitting specs for an existing module

## Output Documents

### 1. CONSTITUTION.md

**Location:** `docs/ryr-docs/<Module>/05_Implementation/<MODULE>_CONSTITUTION.md`

Immutable business rules approved by stakeholders. These CANNOT be changed without
explicit stakeholder approval.

```markdown
# <Module> Constitution

> These rules are IMMUTABLE. Changes require explicit approval from stakeholders.
> Last updated: YYYY-MM-DD

## Rule 1: [Short descriptive name]
**Decision:** [Clear, unambiguous statement of the rule]
**Rationale:** [Why this rule exists - business justification]
**Implications:** [What this means for implementation]
**Approved by:** [Stakeholder name, date]

## Rule 2: ...
```

**What belongs in Constitution:**
- When resources are consumed (e.g., "points deducted at request time, not approval")
- Who can perform what actions (role-based rules)
- State machine rules (valid states and transitions)
- Multi-tenant isolation rules
- Scoring/calculation formulas that are non-negotiable
- Audit requirements

### 2. CLARIFICATIONS.md

**Location:** `docs/ryr-docs/<Module>/05_Implementation/<MODULE>_CLARIFICATIONS.md`

Documented decisions for ambiguous cases. Numbered sequentially. Once documented,
these should NOT be re-asked.

```markdown
# <Module> Clarifications

> Documented decisions for ambiguous cases. Once here, do NOT re-ask.
> Consult this FIRST when encountering ambiguity.

## #1: [The question that was ambiguous]
**Decision:** [What we decided]
**Context:** [Why it was ambiguous, alternatives considered]
**Date:** YYYY-MM-DD

## #2: ...
```

**What belongs in Clarifications:**
- System user UUIDs for automated operations
- Default states for new entities
- Category naming conventions (language, casing)
- Error code organization
- Edge cases not covered by specs
- UI behavior decisions (what happens on X?)

## The Process

### Step 1: Ingest Documentation

Read ALL available documentation for the module. Search in:
- `docs/ryr-docs/<Module>/` - existing project docs
- External docs path (e.g., `_work/apprecio/docs/projects/rr-docs/`)
- Existing code (`supabase/functions/`, `src/hooks/`, `src/pages/`)
- Migration files for implicit schema decisions
- AI-generated analysis documents

### Step 2: Extract Immutable Rules

From documentation and code, identify decisions that are FUNDAMENTAL:
- Look for explicit statements: "must", "always", "never"
- Look for business logic in code that encodes a rule
- Look for validation rules that enforce constraints
- Look for state machine transitions
- Look for access control patterns

### Step 3: Identify Ambiguities

Find cases where:
- Documentation contradicts itself
- Multiple valid interpretations exist
- Existing code makes an implicit decision not documented
- Edge cases are not covered
- Different stakeholders might have different expectations

### Step 4: Resolve with User

Present each ambiguity with:
- The question (clear, specific)
- Available options (with trade-offs for each)
- A recommendation (with justification)
- Impact on implementation

**Use the question tool** to present choices. Do NOT assume answers.

### Step 5: Document Everything

- Every rule in Constitution gets: Decision + Rationale + Implications + Approver
- Every clarification gets: Decision + Context + Date
- Number clarifications sequentially (#1, #2, ...)
- Cross-reference between documents where applicable

## The Golden Rule

**If there is ambiguity about business behavior:**
1. Check CLARIFICATIONS.md (probably already resolved)
2. Verify it does not contradict CONSTITUTION.md
3. If still not found -> ASK the user, NEVER assume

## Quality Checklist

Before marking spec as complete:
- [ ] Constitution has at least 5 immutable rules
- [ ] Clarifications has at least 10 documented decisions
- [ ] No contradictions between Constitution and Clarifications
- [ ] State machine is fully documented (all states, all transitions)
- [ ] Role permissions are documented (who can do what)
- [ ] Points/scoring rules are documented (if applicable)
- [ ] Audit requirements are documented
- [ ] User has reviewed and approved each rule

## Integration

- **Loads skills:** doc-coauthoring (for collaborative writing)
- **Produces input for:** module-auditor (Phase 1), module-plan (Phase 2)
- **Reference:** WorkLife's WORKLIFE_CONSTITUTION.md and WORKLIFE_CLARIFICATIONS.md
- **Template inspiration:** survey-core-expert.md (domain structure)

## Anti-Patterns

- **DO NOT** write specs that are too vague ("the system should be secure")
- **DO NOT** mix implementation details with business rules
- **DO NOT** skip the user review step
- **DO NOT** assume answers to ambiguities
- **DO NOT** create specs that contradict existing WorkLife patterns without justification
