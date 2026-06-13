---
name: pr-review-tests
description: Test suite architecture review for edge functions in a PR. Auto-detects affected APIs, checks doc compliance, production code coverage, duplicated logic, endpoint gaps, and prioritized improvements.
---

# Test Suite Architecture Review

**Usage:** `/pr-review-tests {prNumber}` or `/pr-review-tests {prNumber} --repo owner/repo`

## Instructions

1. Parse the PR number. **Resolve `{repo}`** in this order: (1) `--repo owner/repo` if passed; (2) auto-detect via `gh repo view --json nameWithOwner -q .nameWithOwner` from cwd; (3) if both fail, ask the user and stop.

2. Get PR info and changed files:
```bash
gh pr view {prNumber} -R {repo} --json title,body,headRefOid --jq '{title,body: .body[0:300],head: .headRefOid}'
gh api repos/{repo}/pulls/{prNumber}/files --paginate --jq '.[].filename'
```

3. **Auto-detect affected APIs.** From the changed files, identify:
   - **Direct API changes:** Edge functions under `supabase/functions/*/` — extract function names (e.g., `supabase/functions/training-api/...` → `training-api`).
   - **Shared module changes:** Files under `supabase/functions/_shared/` — trace which edge functions import them.
   - **Test file changes:** Files under `__tests__/` or `tests/e2e/` — map back to their parent API.
   - Exclude `_shared` itself as a module — it's audited through the APIs that import it.
   - Build a deduplicated list of **all affected APIs**.

4. **Read all test convention docs** at root of `supabase/tests/*.md` (root only, not subdirectories). Extract every rule into a checklist. These are the ONLY source of truth for compliance.

5. **For each affected API**, launch parallel agents (1 per API, max 4). Each agent performs the full review for its API:

   **Per-API agent instructions:**

   a) **Inspect production entrypoints** for the module at `supabase/functions/{apiName}/`:
      - `index.ts` (route registry)
      - `routes/*.ts`
      - `services/*.ts`
      - `utils/*.ts`
      - List all endpoints and critical flows.

   b) **Map tests → production code** by scanning `supabase/functions/{apiName}/__tests__/`:
      - Scan imports to see which production modules are actually invoked
      - Identify tests that define local "mock implementations" of business logic (duplicated logic)
      - Classify each test file: imports+calls production code / imports only constants-types / duplicates logic

   c) **Build endpoint coverage map** from:
      - E2E HTTP calls in `tests/e2e/` (e.g., `callWorklifeApi(...)`, `fetch(...)`, etc.)
      - Route-level tests in `__tests__/unit/routes/`
      - Service tests in `__tests__/unit/services/` or `__tests__/service/`

   d) **Check doc compliance** against the checklist from step 4.

6. **Hard guardrails:**
   - Documentation source of truth: ONLY `.md` files at root of `supabase/tests/`.
   - Read-only analysis only.
   - Never claim "not used anywhere" or "no matches found" unless you include the exact search evidence (query + result summary).
   - If you cite doc rules, quote the exact sentence(s) from the doc.
   - E2E tests are in `tests/e2e/*`.

7. **Consolidate results** from all agents into a single report. If multiple APIs are reviewed, show per-API sections within each report section.

8. **Output format (must follow exactly):**

```
## APIs Reviewed
- {api-1}: X test files, Y endpoints
- {api-2}: X test files, Y endpoints

## A) Executive Summary
- **Verdict:** low / med / high risk
- **Top 3 risks:**
  1. ...
  2. ...
  3. ...
- **Top 3 fastest wins:**
  1. ...
  2. ...
  3. ...

## B) Documentation Compliance Matrix

| Category | Status | Doc Quote | Evidence |
|----------|--------|-----------|----------|
| Pyramid / suite separation | ✅/⚠️/❌ | "..." | file:line excerpt |
| Naming conventions | ✅/⚠️/❌ | "..." | file:line excerpt |
| AAA & clarity | ✅/⚠️/❌ | "..." | file:line excerpt |
| Mocks realism & shared helpers | ✅/⚠️/❌ | "..." | file:line excerpt |
| Fixtures/builders usage | ✅/⚠️/❌ | "..." | file:line excerpt |
| Service test setup/cleanup | ✅/⚠️/❌ | "..." | file:line excerpt |
| Security testing conventions | ✅/⚠️/❌ | "..." | file:line excerpt |
| Property-based testing | ✅/⚠️/❌ | "..." | file:line excerpt |
| "Test behavior not implementation" | ✅/⚠️/❌ | "..." | file:line excerpt |

## C) Real Production Code Exercised?

### Tests that import and CALL production code
- file → calls function/module

### Tests that only import constants/types
- file → imports X (no execution)

### Duplicated-logic tests (≥5 examples)
- file: description of duplicated logic

## D) Endpoint / Critical-Flow Coverage Map

### {api-name} ({N} endpoints)

| Endpoint | Method | Unit | Service | E2E | Gap? |
|----------|--------|------|---------|-----|------|
| /path | GET | ✅/❌ | ✅/❌ | ✅/❌ | search evidence |

## E) Prioritized Improvements

| # | Impact | API | Where to add | Production target | Example test name |
|---|--------|-----|-------------|-------------------|-------------------|
| 1 | ... | ... | ... | ... | ... |

Standard: {N} APIs reviewed, {X} test files analyzed, {Y} endpoints mapped, {Z} gaps identified.
```

## Idioma

TODO el output debe ser en **español neutro latinoamericano**. Nombres de archivos, variables y código se mantienen en inglés. Severidades en inglés (MUST FIX, SHOULD FIX, CONSIDER).
