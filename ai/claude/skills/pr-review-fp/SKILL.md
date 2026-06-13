---
name: pr-review-fp
description: Verify agent findings against the actual PR diff. Classifies each finding as True Positive, False Positive, or Needs Review using domain-specific heuristics.
---

# TP/FP Analysis

**Usage:** `/pr-review-fp {prNumber}` (operates on findings provided in-conversation, e.g. from a prior `/pr-review` run)

## Step 1: Retrieve Data

1a. **Source of findings:** This skill is standalone — findings must be provided in the current conversation context (typically from a prior `/pr-review` run, or pasted by the user). If no findings are available, ask the user to provide them or to run `/pr-review {prNumber}` first.

1b. Get fresh diff:
```bash
gh pr diff {prNumber} -R {repo} > /tmp/pr{prNumber}.diff
```

**Resolve `{repo}`** in this order: (1) `--repo owner/repo` if passed; (2) auto-detect via `gh repo view --json nameWithOwner -q .nameWithOwner` from cwd; (3) if both fail, ask the user and stop.

1c. Count findings by category and severity. Report: `"Agent: X findings (C:N H:N W:N S:N)"`

## Step 2: Group Findings by Domain

Classify each finding into one of 3 domains based on its category, file path, and issue text:

| Domain | Categories / Signals |
|--------|---------------------|
| **Security + Auth** | auth, idor, secrets, rls, tenant, cors, xss, sanitization, injection, access control, CSRF |
| **SQL + Migrations** | SQL functions, migrations, indexes, constraints, LIMIT, transactions, SECURITY DEFINER, RLS policies |
| **Infra + Frontend** | error handling, complexity, React, i18n, Deno env, YAML, test coverage, validation, types |

## Step 3: Launch Domain-Based Agents

Launch **3 agents in parallel**, one per domain. Each agent receives:
- All findings for its domain (every severity — no sampling)
- The full diff
- The FP heuristics checklist for its domain (from the sections below)

If total findings exceed 60, Agent 3 may sample SUGGESTIONs (max 15), but must verify all CRITICAL + HIGH + WARNING.

Each agent must verify EVERY finding by:
1. Locating the file:line in the diff
2. Reading surrounding context (±30 lines)
3. Applying the domain heuristics below
4. Classifying as **TP**, **FP**, or **NEEDS_REVIEW**

---

## Security + Auth FP Heuristics (Agent 1)

### S1: Sanitization before dangerous command
If finding mentions "command injection," "shell injection," or targets `execSync`/`exec`/`spawn`:
- Search for `sanitize*()`, `validate*()`, `escape*()`, `clean*()` within 500 chars before the dangerous call.
- If found → **FP**. Cite the sanitization function.

### S2: DOMPurify covers XSS
If finding mentions "XSS" or "dangerouslySetInnerHTML":
- Search the same file for `DOMPurify.sanitize()`.
- If the sanitized value feeds into `__html` → **FP**.

### S3: escapeHtml in interpolation
If finding mentions "XSS" and code uses template literals/interpolation:
- Search for `escapeHtml()` applied to the interpolated value.
- If found → **FP**.

### S4: Tenant derived from server context
If finding mentions "client-supplied tenant_id" or "IDOR":
- Check whether `tenantId` comes from `c.get('auth')`, `getSession()`, or `user_roles.eq('user_id', user.id)`.
- If server-derived (not from request body/params) → **FP**.

### S5: Brand validation present
If finding mentions "missing brand validation":
- Search for `findBrandWithFallback()`, `validateBrand()`, `.eq('brand_id', ...)`.
- If present and used → **FP**.

### S6: Global middleware covers route
If finding mentions "missing auth on route" or "unprotected endpoint":
- Check if the file has `app.use('*', authMiddleware)` or the handler accesses `c.get('auth')`.
- If global middleware is applied → **FP**.

### S7: Deno.env.get in edge functions
If finding mentions "secrets in source" or "hardcoded credentials" and file is under `supabase/functions/`:
- `Deno.env.get()` is the standard Supabase edge function pattern for reading env vars at runtime.
- → **FP**.

### S8: Health endpoints are intentionally public
If finding targets `/health`, `/healthz`, `/status`, `/ping` for missing auth or CORS:
- These are intentionally unauthenticated monitoring endpoints.
- → **FP**.

### S9: Sanitization before validation call
If finding mentions "validation bypass" and code has `sanitize*()` called before `validate*()`:
- Example: `sanitizeMissionType()` → `validateMission()`.
- If sanitization precedes validation → **FP**.

---

## SQL + Migrations FP Heuristics (Agent 2)

### Q1: SECURITY DEFINER already present
If finding says "missing SECURITY DEFINER":
- Search the CREATE FUNCTION statement for `SECURITY DEFINER`.
- If present → **FP**.

If finding says "SECURITY DEFINER without tenant validation":
- Search the function body for `auth.uid()`, `get_user_tenant()`, or `WHERE tenant_id = (SELECT ... auth ...)`.
- If tenant validation found → **FP**.

### Q2: Fixed in later migration
If finding targets a migration for missing column/RLS/constraint:
- Check if a later migration in the same PR adds it (e.g., `ALTER TABLE ... ADD COLUMN tenant_id`).
- If fixed later → **FP**.

### Q3: Password hashing present
If finding mentions "plaintext password" or "password storage":
- Search for `crypt()`, `gen_salt()`, `bcrypt`, `argon2` in the function/migration.
- If hashing found → **FP**.

### Q4: Atomic RPC covers transaction
If finding mentions "no transaction" or "missing BEGIN/COMMIT":
- Search for `.rpc('*_atomic*')` calls, or SQL function with `SECURITY DEFINER` containing 2+ INSERT/UPDATE operations.
- If found → **FP** (the RPC handles atomicity internally).

### Q5: Index already exists
If finding suggests "add index" on a column:
- Search the same migration file for `CREATE INDEX ... ON table(column)`.
- If found → **FP**.

### Q6: WHERE id = PK eliminates LIMIT need
If finding says "missing LIMIT":
- Check if the query has `WHERE id = $param` or `WHERE uuid = $param` (primary key lookup).
- Single-row guaranteed by PK → **FP**.

### Q7: FK ON DELETE already specified
If finding mentions "missing ON DELETE" behavior:
- Check the REFERENCES clause for `ON DELETE CASCADE`, `ON DELETE SET NULL`, or `ON DELETE RESTRICT`.
- If specified → **FP**.

### Q8: SELECT INTO STRICT
If finding says "missing LIMIT" and query uses `SELECT INTO ... STRICT`:
- STRICT raises exception if 0 or >1 rows → single-row guaranteed.
- → **FP**.

### Q9: Seed file security suppression
If file path contains `seed`, `dev-data`, or `fixtures`:
- Suppress findings about hardcoded passwords, credentials, missing triggers, replication.
- → **FP** (development-only data).

### Q10: IF NOT EXISTS already present
If finding says "add IF NOT EXISTS":
- Check ±3 lines of the SQL statement for existing `IF NOT EXISTS`.
- If present → **FP**.

### Q11: Safe PostgreSQL parameter types
If finding mentions "SQL injection" and the function parameters are typed (`UUID`, `TEXT`, `INTEGER`, `BOOLEAN`):
- Typed parameters prevent injection in PostgreSQL functions.
- → **FP**.

### Q12: UPDATE/DELETE with WHERE clause nearby
If finding says "UPDATE/DELETE without WHERE":
- Search ±20 lines for a WHERE clause on the same statement.
- If found → **FP** (finding missed multi-line statement).

---

## Infra + Frontend FP Heuristics (Agent 3)

### I1: React Query error handling
If finding mentions "missing error handling" and the component uses `useQuery`/`useMutation`:
- Check for `isError`, `error` destructuring, or error UI rendering.
- If error state is handled → **FP**.

### I2: Dashboard uses real hooks
If finding mentions "data from mocks" or "mock data":
- Check if the component imports real data hooks (`useTrainingStats`, `useTopMentors`, `useDashboardData`, etc.).
- If real hooks used → **FP**.

### I3: Redirect with logging
If finding mentions "redirect without context" or "silent redirect":
- Check ±10 lines for `console.log`, `console.warn`, `console.error`, or `logger.*`.
- If logging present → **FP**.

### I4: Pre-validated input
If finding mentions "injection" or "unsanitized input":
- Check preceding 30 lines for regex validation, `parseInt()`, `Number()`, `z.string()`, Zod schema `.parse()`.
- If input is validated before use → **FP**.

### I5: Normal complexity flagged as HIGH
If finding says "high complexity" targeting a React hook (uses multiple hooks), a REST route handler (auth + validation + logic), or a component with static arrays:
- These are normal patterns, not HIGH-severity issues.
- → **FP** or downgrade to SUGGESTION.

### I6: Commented-out code in context
If finding's target line is inside a comment block (3+ consecutive `//` lines or `/* */` block):
- The code is intentionally commented, not a live issue.
- → **FP**.

### I7: Valid test mocking patterns
If finding says "test uses mocks instead of real code":
- Check if the test mounts real route handlers with `app.route()` and has security/auth assertions.
- If testing real handlers → **FP**.

### I8: Generated types file
If file is `types.ts`, `generated.ts`, or contains `// This file is auto-generated`:
- Suppress complexity, naming, and validation findings on generated files.
- → **FP**.

---

## Hard Guardrails

- **Evidence required:** Never classify a finding as FP without citing the specific line or pattern that mitigates it.
- **FP format:** `FP: {file}:{line} — {heuristic ID} — {evidence snippet}`
- **TP format:** `TP: {file}:{line} — {why it's real} — no mitigating pattern found`
- **NEEDS_REVIEW format:** `NEEDS_REVIEW: {file}:{line} — {why unclear} — {what to check manually}`
- **Diff-only rule:** If the finding references a file:line NOT present in the diff, classify as **FP** (finding targets unchanged code).
- **No speculation:** If you cannot find the referenced code in the diff, do not guess — classify as NEEDS_REVIEW.

---

## Step 4: Output Format

```
## PR #{prNumber} TP/FP Analysis

### Findings Summary
| Severity | Total | TP | FP | Needs Review | Precision |
|----------|-------|----|----|-------------|-----------|
| CRITICAL |       |    |    |             |           |
| HIGH     |       |    |    |             |           |
| WARNING  |       |    |    |             |           |
| SUGGESTION|      |    |    |             |           |
| **Total**|       |    |    |             |           |

### Domain Breakdown
| Domain | Total | TP | FP | Top FP Heuristic |
|--------|-------|----|----|------------------|
| Security + Auth |  |  |  |                  |
| SQL + Migrations|  |  |  |                  |
| Infra + Frontend|  |  |  |                  |

### False Positives
| # | File:Line | Severity | Finding | Heuristic | Evidence |
|---|-----------|----------|---------|-----------|----------|

### True Positives
| # | File:Line | Severity | Finding | Why TP |
|---|-----------|----------|---------|--------|

### Needs Review
| # | File:Line | Severity | Finding | Why Unclear |
|---|-----------|----------|---------|-------------|

### Recommendations
- If precision < 80%: identify which domain/category produces the most FPs.
- List top 3 FP patterns to suppress in agent prompts for next run.

Standard: {N} findings analyzed, {TP} true positives, {FP} false positives, {NR} needs review. Precision: {X}%.
```

## Idioma

TODO el output debe ser en **español neutro latinoamericano**. Nombres de archivos, variables y código se mantienen en inglés. Severidades en inglés (MUST FIX, SHOULD FIX, CONSIDER).
