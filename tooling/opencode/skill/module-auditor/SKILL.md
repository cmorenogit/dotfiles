---
name: module-auditor
description: Use when auditing an existing or new R&R module to assess maturity, gaps, and security posture against WorkLife reference patterns.
---

# Module Auditor

## Overview

Audit any R&R module by comparing its implementation against the WorkLife reference
architecture. Produces a maturity scorecard, gap analysis, and creates bd issues for
all findings.

**Announce at start:** "I'm using the module-auditor skill to audit the <MODULE> module."

## When to Use

- Before starting work on an existing module (refactor/enhance)
- Before starting a new module from scratch (blueprint mode)
- After major implementation phases to measure progress
- When evaluating security posture

## The Audit Process

### Step 1: Identify Module Artifacts

Search for ALL existing code related to the module across both repos:

**Back-pulse (backoffice + API):**
- Edge Functions: `supabase/functions/<module>*/`
- Hooks: `src/hooks/` files containing `<module>`
- Pages: `src/pages/` files containing `<module>`
- Components: `src/components/<module>/`
- Migrations: `supabase/migrations/` files containing `<module>`
- Tests: `supabase/functions/<module>*/__tests__/`
- Documentation: `docs/ryr-docs/<Module>/`

**App-rr (collaborator app):**
- Pages/Components in `/Users/cmoreno/Code/work/app-rr-cesar/src/`

### Step 2: Compare Against WorkLife Reference

Score each layer 0-10 against WorkLife patterns:

| Layer | WorkLife Pattern | What to Check |
|-------|-----------------|---------------|
| **DB Schema** | 5+ tables, enums, 20+ indices, RLS policies, RPCs, audit table | Table count, index coverage, RLS completeness, constraint integrity |
| **Edge Functions** | Single consolidated `<module>-api/` with modular files | File structure: index.ts + errors.ts + validators.ts + state-machine.ts |
| **Error Catalog** | ~50 typed error codes, Spanish messages, HTTP status codes, interpolation | Exists? How many codes? Proper HTTP statuses? AppError class? |
| **Validators** | Centralized, field whitelists, pure functions exported for testing | Exists? Coverage? Mass assignment protection? Testable? |
| **State Machine** | Explicit transition map with role guards | Exists? All transitions guarded? Dead states? |
| **Audit Trail** | Dedicated audit table with event types | Exists? Event coverage? Who/what/when captured? |
| **Auth/Roles** | Service class with getTenantId(), getUserRole(), hasRole() | Role checks in EF? Not just RLS? Tenant from auth not body? |
| **Backoffice UI** | Pages in `src/pages/<module>/`, hooks in `src/hooks/<module>/` | Connected to API? Mock data? Dead buttons? |
| **App UI** | Full integration, real API calls, proper types | Connected? Mock? Type compatibility with API? Navigation? |
| **Testing** | Unit (60%) + Service (30%) + E2E (10%), naming A-<M>-NNN | Test count, pyramid balance, naming convention |
| **Security** | Field whitelist, state guards, tenant isolation, input validation | CWE-915, CWE-862, CWE-20, CWE-284, CWE-639, CWE-209 |

### Step 3: Security Deep-Dive (CWE Checklist)

For each endpoint in the Edge Functions, check:

| CWE | Vulnerability | What to Look For |
|-----|--------------|------------------|
| CWE-915 | Mass Assignment | `...body` spread to INSERT/UPDATE without field whitelist |
| CWE-862 | Missing Authorization | Relies only on RLS, no role check in Edge Function |
| CWE-20 | Improper Input Validation | No server-side validation, TODO comments for validation |
| CWE-284 | Improper Access Control | State transitions without guards, any-state-to-any-state |
| CWE-639 | Insecure Direct Object Reference | `tenant_id` from body instead of auth token |
| CWE-209 | Error Information Exposure | Raw error messages in responses, all errors return 400 |
| CWE-287 | Improper Authentication | Missing auth check on endpoints |
| CWE-840 | Business Logic Error | Business rules not matching Constitution |

### Step 4: Produce Scorecard

Output a maturity table:

```markdown
## Maturity Scorecard: <Module>

| Layer | Score | Assessment | Key Gaps |
|-------|-------|------------|----------|
| DB Schema | X/10 | ... | ... |
| Edge Functions | X/10 | ... | ... |
| Error Catalog | X/10 | ... | ... |
| Validators | X/10 | ... | ... |
| State Machine | X/10 | ... | ... |
| Audit Trail | X/10 | ... | ... |
| Auth/Roles | X/10 | ... | ... |
| Backoffice UI | X/10 | ... | ... |
| App UI | X/10 | ... | ... |
| Testing | X/10 | ... | ... |
| Security | X/10 | ... | ... |
| **OVERALL** | **X/10** | ... | ... |
```

### Step 5: Create bd Issues

For each gap found, create a bd issue:

```
bd create "[<module>] <gap description>" -t <bug|feature|task> -p <0-4>
```

Priority mapping:
- **P0:** Security vulnerabilities (CWE findings), missing auth
- **P1:** Missing tests for existing functionality, mock data that should be real
- **P2:** Missing features vs WorkLife, code quality issues
- **P3:** i18n, dead code cleanup, optimization

### Step 6: Save Report

Save to: `docs/audits/<module>-audit-YYYY-MM-DD.md`

## Module-Specific Modes

### For Existing Modules (code exists)
Focus on: what to REFACTOR + what to ADD + what to REMOVE (dead code)
Compare current state against WorkLife for each layer.

### For New Modules (starting from scratch)
Focus on: BLUEPRINT of what to build, following WorkLife architecture exactly.
Produce a file tree showing every file that needs to be created:

```
supabase/functions/<module>-api/
├── index.ts
├── errors.ts
├── validators.ts
├── state-machine.ts
├── __tests__/
│   ├── unit/
│   ├── service/
│   └── helpers/
src/pages/<module>/
src/hooks/<module>/
src/components/<module>/
supabase/migrations/YYYYMMDD_<module>_schema.sql
docs/ryr-docs/<Module>/05_Implementation/
├── <MODULE>_CONSTITUTION.md
└── <MODULE>_CLARIFICATIONS.md
```

## Integration

- **Loads skills:** software-architecture, supabase-postgres-best-practices
- **Uses agents:** security-expert (for CWE deep-dive)
- **Produces input for:** /module-plan (Phase 2)
- **Reference:** WorkLife's `worklife-api/` as gold standard

## Red Flags

- **Score < 3/10 on Security:** STOP. Hardening is P0 before any feature work.
- **Score 0/10 on Testing:** Plan MUST include testing foundation before new features.
- **Mock data in production code:** Every mock is a gap that needs an API connection.
