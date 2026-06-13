---
name: pr-review
description: Full PR review pipeline — 2-pass local analysis (Haiku + Opus), cross-cutting concerns, tests, scope, audit, and consolidated report. Standalone (no backend required).
---

# Full PR Review Pipeline (2-Pass Local, Standalone)

**Usage:** `/pr-review {prNumber} [--repo owner/repo] [--skip-agent] [--skip-scope]`

This skill is **fully standalone**: it uses only `gh` CLI, the `Agent` tool, and writes a final `.md` report locally. No backend persistence is required.

## Pipeline

Execute these steps in order. If a step fails, continue with the next.

### Step 0: Setup

1. Parse arguments. **Resolve `{repo}`** in this order:
   1. If `--repo owner/repo` was passed → use it.
   2. Else, auto-detect from cwd: `gh repo view --json nameWithOwner -q .nameWithOwner` (works if cwd is inside a git repo with a GitHub remote).
   3. If auto-detect fails (not a git repo, or no remote) → ask the user for `--repo owner/repo` and stop.

2. Get PR info:
```bash
gh pr view {prNumber} -R {repo} --json title,additions,deletions,changedFiles,headRefName
```

2.5. **Iteration Contract setup** (read `knowledge/iteration-contract.md` for the full rules):
   - **Detect previous iter:** check if `~/Code/_vault/_work/apprecio/projects/{project}/reviews/{repo}/pr{prNumber}-review-report*.md` exists (project from repo: apprecio-pulse/ryr-39255 → rr). If yes, this is iter N≥2.
   - **Extract bar of trunk** from the PR body. If declared explicitly (`bar=P0/P1`, `solo MUST FIX bloquea`, etc.) → use it. If not declared → default to `MUST-FIX-or-above` and note it explicitly in the report.
   - **If iter N≥2:**
     - Read the previous report. Extract: (a) previous SHA, (b) conditions list, (c) surface declared as "✅ Auditado".
     - Compute file delta: `gh api "repos/{repo}/compare/{prev_sha}...{curr_sha}" --jq '.files[].filename'`. This delta is used in Step 7 to classify origin of any new finding (REGRESSION vs DEPTH vs SCOPE_EXPANSION — see contract Rule 1).
     - Re-verify each previous condition: closed / partial / not closed. Record evidence.
   - **If iter == 3 and bloqueantes legítimos persist:** prepare escalation block per contract Rule 4. Do not start iter 4.

2.6. **Domain detection-rules loading:** read `knowledge/detection-rules/README.md` (the index). For each rule, evaluate its **Trigger** section against the PR's file list and diff. If a trigger matches:
   - Load the full rule file (e.g., `knowledge/detection-rules/economic-grants.md`).
   - Inject the rule content into the prompt of every subagent the rule declares in **"Skills que la consumen"** (typically one or more of G1–G5 and/or the CCC agent).
   - Apply the rule's severity table as authoritative for matched patterns.

   If no rule's trigger matches the PR, skip — domain rules are opt-in by trigger to avoid wasted tokens.

   Currently shipped domain rules (verify against `README.md` for the live list):
   - **economic-grants** — triggers on `point_transactions`, `wallet_ledger`, `grant_*` RPCs, `economic-grant` / `*-grant*` / `reward-redemption` / `gift-card-*` / `wallet-funding-*` edge functions. Consumed by G2 and CCC.
   - **migration-timestamps** — triggers when the PR adds files under `supabase/migrations/*.sql` with `YYYYMMDDHHMMSS_` prefix. Detects intra-PR collisions, inter-branch collisions against `main`, out-of-order timestamps (< max in main), and future timestamps (> today + 30d). Consumed by G3 and CCC.

3. Get full file list (paginated, up to 300 files):
```bash
gh api "repos/{repo}/pulls/{prNumber}/files?per_page=100&page=1" --jq '.[].filename'
gh api "repos/{repo}/pulls/{prNumber}/files?per_page=100&page=2" --jq '.[].filename'
gh api "repos/{repo}/pulls/{prNumber}/files?per_page=100&page=3" --jq '.[].filename'
```

4. Classify files into 5 groups using the rules below. Files matching no group are skipped.

**File Classification Rules (first match wins for primary group; some files appear in multiple groups):**

| Group | File Patterns | Focus |
|-------|--------------|-------|
| G1: XSS + Secrets | `*.tsx`, `hooks/*.ts`, `_shared/supabase-client.ts`, `_shared/crypto-utils.ts` | dangerouslySetInnerHTML, innerHTML, hardcoded API keys/tokens/passwords |
| G2: CORS + Auth + IDOR | `_shared/auth*.ts`, `_shared/cors.ts`, `middleware/auth*.ts`, `services/*.ts`, edge function `index.ts` | Wildcard CORS, missing auth middleware, tenant_id not from user_roles |
| G3: SQL + RLS + Cron | `*.sql`, `*cron*.sql`, `*-cron*.sql`, `services/*.ts` (query patterns) | Missing RLS, NULL tenant_id, RLS policies without tenant_id filter, FK without ON DELETE, SQL injection, **cron canonical format violations** (non-canonical URL, hardcoded secrets in headers, settings without `app.settings.*` namespace, tagged dollar quotes, direct-sql cron without `cron-direct/ALLOWED_ACTIONS` update) |
| G4: Validation + Errors | `schemas/*.ts`, `*schema*.ts`, `error-responses.ts`, `routes/*.ts` | Missing Zod constraints, stack traces leaked, inconsistent validation |
| G5: Flags + i18n + Cmd Palette | edge function `index.ts`, `locales/*.json`, `*.tsx` (forms), `feature-flag*`, `moderation*`, `src/App.tsx`, `src/components/command-palette/*`, `src/hooks/useCommandPalette*`, `src/locales/*/command-palette.json` | Missing feature flag middleware, hardcoded Spanish, locale parity gaps, **command palette catalog out-of-sync with routes/flags** (new route without entry, entry with broken URL, `useFeatureFlag` gate without `requiresFlag` in catalog, missing label in any of 4 locales, kill-switch not respected by entry) |

**Skip patterns:** `*.md`, `*.json` (non-locale), `config.*`, `package.json`, `__tests__/*`, `*.spec.ts`, `*.test.ts`, `.gitignore`, `tsconfig*`

If a group has 0 files, that subagent is NOT spawned.

---

### Step 1: Pass 1 — Haiku Analysis (5 parallel subagents)

Unless `--skip-agent` is specified:

Launch all needed groups via `Agent(model: "haiku")` in a **single message** (parallel execution). Each subagent:

- Receives: detection rules + anti-FP rules + assigned file list
- Reads each file via: `gh api "repos/{repo}/contents/{path}?ref={branch}" --jq '.content' | base64 -d`
- Skips files > 500 lines (likely generated code)
- Returns findings as structured text

**Anti-FP rules to embed in EVERY subagent prompt** (see `knowledge/acceptable-patterns.md` for full list):
- Tenant ID obtained from `user_roles` query by `user.id` (server-derived) = NOT IDOR
- CORS wildcard on health endpoints (`/health`, `/healthz`, `/status`, `/ping`) = acceptable
- Seed file data (`*seed*.sql`): passwords, trigger disabling, truncation = acceptable
- `t('key', { defaultValue: 'Texto en español' })` = NOT hardcoded string (project's i18n pattern)
- Domain constants (25/50/75/100 thresholds, 86400000 ms/day) = NOT magic numbers
- React form patterns (onValueChange resets, ternary chains ≤3) = NOT code smells
- SQL migration patterns (ON CONFLICT DO UPDATE, DROP+CREATE VIEW) = acceptable
- IDOR has 100% FP rate in this repo — only report if 100% certain
- CORS has 100% FP rate in this repo — only report if 100% certain
- **Global middleware coverage (S6):** Before reporting "missing auth", "missing flag check", or "sub-flag without master flag" on a route, check the edge function's `index.ts` for `app.use('*', middleware)`. If global middleware covers the route → NOT a finding. Read index.ts BEFORE reporting.
- **Internal server-to-server services (S4+):** Files in `_shared/*-service.ts` are called by edge functions, not HTTP clients. Do NOT report "tenantId not validated vs JWT" — the calling function already validated it.
- **Backend API validation messages in English:** Zod `.message()` in edge functions are for API consumers (developers), not end users. Only flag i18n for user-facing strings in `.tsx` files.
- **Normal complexity (I5):** React hooks with multiple sub-hooks, route handlers with auth+validation+logic, components with static arrays = normal patterns, NOT code smells.
- **Manager-by-role anti-pattern (P14):** This is NOT an anti-FP rule — it's an inverse hint. Any `roles.includes('manager')`, `userRole.role === 'manager'`, `['admin', 'manager', 'hr'].includes(role)`, or `isAdminOrManager(ctx)` whose body only reads `roles`/`role` IS a finding (MUST FIX) when used as an authorization gate. Canonical check is `rpc('is_org_manager', { _user_id, _tenant_id })` or query against `departments.manager_id` / `teams.manager_id`. Don't suppress these — they survive Step 6 as TP. See `knowledge/acceptable-patterns.md` §14.
- **Cron migrations (anti-FP):** `cron.unschedule` puro (sin reschedule subsiguiente) es aceptable — no flaggear. `cron.alter_job` que cambia SOLO el schedule (sin tocar URL/headers/body) también es aceptable. La regla canonical aplica a `cron.schedule` que registra o reemplaza un job (`unschedule + schedule` en la misma migracion). Ver `knowledge/acceptable-patterns.md` §15.
- **Notification reads (anti-FP):** Queries `SELECT` sobre `in_app_notifications` (listar notificaciones del usuario, contar unread) son aceptables — la regla NOTIFICATIONS aplica solo a mutaciones (INSERT/UPDATE/DELETE). Ver `knowledge/acceptable-patterns.md` §16.
- **Notification-purge / notification-retry direct table access (anti-FP):** estas dos edge functions operan directo sobre `in_app_notifications` / `notification_delivery_log` por diseño — su único propósito ES mantener esas tablas. No flaggear. Ver §16.

**Subagent prompt template per group:**

```
You are a security auditor scanning PR #{prNumber} in repo {repo} (branch: {branch}).

## Detection Rules
{detection_rules_for_this_group}

## Anti-FP Rules (CRITICAL — apply BEFORE reporting any finding)
{anti_fp_rules_above}

## Files to Scan
{file_list_for_this_group}

Fetch each file via: gh api "repos/{repo}/contents/{path}?ref={branch}" --jq '.content' | base64 -d

## Instructions
1. Fetch and read each file fully
2. Apply detection rules
3. Apply anti-FP rules BEFORE reporting — verify each finding against the code
3.5. SELF-CHECK before reporting each finding:
   - "Could global middleware in index.ts already cover this?" → If maybe, fetch and read index.ts first.
   - "Is this file a _shared service called by other edge functions internally?" → If yes, the caller handles auth/tenant validation.
   - "Is this a backend-only message (Zod error, log, API response)?" → If yes, English is acceptable.
   If any self-check suggests FP, DROP the finding silently.
4. Report findings with: file, line, severity (CRITICAL/HIGH/WARNING/SUGGESTION), issue (in Spanish), confidence (0-100)
5. If no findings, explicitly state "0 findings"
6. Summary count at the end
```

**Detection rules per group:**

- **G1 (XSS + Secrets):** `dangerouslySetInnerHTML` with user input, `innerHTML`, `document.write()`, hardcoded API keys/tokens/passwords (NOT `process.env`/`Deno.env.get()`), credentials in config files
- **G2 (CORS + Auth + IDOR + Manager-by-role):** `Access-Control-Allow-Origin: *` in production, missing auth middleware on routes, queries without `.eq('tenant_id', tenantId)` where tenantId is NOT server-derived, bypassable auth checks. **Plus**: any authorization gate that decides "user is manager" via `roles.includes('manager')`, `userRole.role === 'manager'`, `['admin','manager','hr'].includes(role)`, or via a helper (`isAdminOrManager`, `isManager`, `requireManager`) whose body only reads `roles`/`role` and never calls `rpc('is_org_manager', ...)` nor queries `departments.manager_id`/`teams.manager_id`. Canonical RPC: `is_org_manager(_user_id, _tenant_id)` from migration `20260206152933`. Severity: MUST FIX. When you find this, also grep the same PR for `is_org_manager` — if SOME files in the same PR use the RPC and OTHERS use the role string, that's an automatic MUST FIX (mixed pattern). See knowledge/acceptable-patterns.md §14.
  - **Domain rule — economic grants (load conditionally per Step 2.6):** if the PR touches `point_transactions`, `wallet_ledger`, `grant_*` RPCs, or `economic-grant`/`*-grant*`/`reward-redemption`/`gift-card-*`/`wallet-funding-*` edge functions, load `knowledge/detection-rules/economic-grants.md` and apply its severity table. Key patterns: `INSERT INTO point_transactions` direct for grants = MUST FIX; `.rpc('grant_economic')` direct from new edge function = WARN; new SQL RPC inserting into `point_transactions` without calling `grant_economic` internally = MUST FIX. Anti-FP: INSERTs into `wallet_ledger` for **consumption** (reward-redemption, gift-cards, wallet-funding) with caller-level governance = valid, do NOT flag.
- **G3 (SQL + RLS + Cron):** Tables without RLS enabled, `tenant_id` allowing NULL, **RLS policies that filter only by `user_id` without `tenant_id`** (multi-tenant isolation gap — policies must validate tenant membership via `tenant_id IN (SELECT tenant_id FROM user_roles WHERE user_id = auth.uid())` or equivalent), FK without ON DELETE (orphan risk), SQL injection (string interpolation), missing indexes on high-query columns. For `*seed*.sql`: suppress all findings.
  - **Domain rule — migration timestamps (load conditionally per Step 2.6):** if the PR adds files under `supabase/migrations/*.sql`, load `knowledge/detection-rules/migration-timestamps.md` and apply its checks: intra-PR prefix collision (MUST FIX), inter-branch prefix collision against `main` (MUST FIX), out-of-order timestamp `< max(main)` (MUST FIX), future timestamp `> today + 30d` (WARN), invalid format (MUST FIX). Run the verification commands from that rule's "Verificación rápida" section to compute findings programmatically. Suggest the exact rename fix as a Quick Win.
  - **Cron canonical format violations** (PR #355 ground truth — see `docs/cron-canonical-format.md`):
    - URL not matching `current_setting('app.settings.supabase_url', true) || '/functions/v1/<name>'` → MUST FIX
    - Hardcoded URL (`https://*.supabase.co`) → MUST FIX
    - Settings without `app.settings.*` namespace (`app.supabase_url`, `app.service_role_key`) → MUST FIX (NULL in prod)
    - Hardcoded JWT/secret in header value (`'Bearer eyJ...'`, `'x-cron-secret', 'literal'`) → CRITICAL (token in public repo)
    - Tagged dollar quotes (`$tag$...$tag$`) → MUST FIX (parser rejects)
    - `cron.schedule` with direct-sql body but `cron-direct/index.ts` not in PR → MUST FIX (preview parity broken)
- **G4 (Validation + Errors):** Zod schemas without `.min()`/`.max()`, missing `.email()`/`.uuid()`, stack traces in error responses, `error.message` exposed to client, inconsistent validation between similar endpoints
- **G5 (Flags + i18n + Cmd Palette):** Feature flag middleware missing (compare all edge function index.ts files), sub-flag without master flag check, Zod messages hardcoded in Spanish (not using i18n), missing locale keys in FR/PT that exist in ES.
  - **Command Palette catalog sync (PR #215/#359 ground truth — see CCC CMD_PALETTE section):**
    - New `<Route path="/X">` in `src/App.tsx` without matching entry in `pageCatalog` → MUST FIX (admin-accessible route invisible via ⌘K)
    - New `useSearchParams` for `?tab=X` in a page without entry `category: 'tab_deep_link'` in catalog → MUST FIX
    - New `useEffect` reading `searchParams.get('action')` to open a modal without entry `category: 'modal_action'` → MUST FIX
    - Renamed/deleted route still present in `catalog.ts` with old URL → MUST FIX (entry navigates to 404)
    - New `useFeatureFlag('X')` gating a navigable section without entry `requiresFlag: 'X'` in catalog → MUST FIX (zombie entry when flag OFF)
    - Entry with `requiresFlag: 'X'` where `'X'` not in `KnownFeatureFlag` union → MUST FIX (TS error in client)
    - Catalog entry with `labelKey: 'X'` missing in any of `src/locales/{en,es,fr,pt}/command-palette.json` → MUST FIX
    - Kill-switch added for a navigable module without entry `requiresFlag: '<kill_switch>'` → MUST FIX (module off but discoverable via palette)

After all subagents complete, collect all findings and report:
```
Pass 1: X findings (C:N H:N W:N S:N) — Haiku, {N} files analyzed
```

---

### Step 2: Pass 2 — Opus Targeted Analysis (1-2 subagents)

**Skip if:** Pass 1 found 0 findings AND PR has no cross-cutting files (`_shared/*`, `middleware/auth*`, `feature-flag*`).

Otherwise, launch via `Agent(model: "opus")`:

**Subagent A (cross-file backend):** Always runs if Pass 2 triggers.
- Input: All Pass 1 findings + flagged files + always-review files (`_shared/*`, `middleware/*`)
- Focus:
  - Auth flow tracing: does middleware actually protect the flagged route?
  - Sub-flag → master flag coherence (e.g., `ecards_moderation_enabled` must check `ecards_grupales_enabled`)
  - Tenant isolation across service boundaries
  - `console.log` / debug statements in production code
  - pg_cron / scheduled task configuration gaps
  - **Cron canonical format (PR #355 ground truth):** read full migration body for each `cron.schedule` call. Verify URL canonica, settings namespaced `app.settings.*`, no hardcoded secrets in headers, no tagged dollar quotes. For direct-sql cron: verify `cron-direct/index.ts` is also in the PR with action added to `ALLOWED_ACTIONS`. For HTTP cron: verify target edge function validates `x-supabase-cron` o `x-cron-secret` in its `index.ts`/routes. See `docs/cron-canonical-format.md` in the product repo.
  - **Notification system bypass:** trace any INSERT/UPDATE to `in_app_notifications` or `notification_delivery_log`. The ONLY valid emitters are `_shared/notification-service.ts` (`emitNotificationEvent`), `notification-api`, `notification-purge`, `notification-retry`. Any other edge function writing to those tables = MUST FIX (bypasses preference + feature-flag chain).
  - **Shared module evasion:** for each flagged behavior, check if a `_shared/` canonical exists. CORS hardcoded → `_shared/cors.ts`; manual JWT parse → `_shared/auth-utils.ts`; direct external fetch → `_shared/integration-utils.ts:fetchWithResilience`; new rate-limiter → `_shared/rate-limit.ts`; direct storage call → `_shared/storage-adapter/`; ad-hoc logging without `observabilityMiddleware`. Evasion of an existing shared = MUST FIX.
  - **Race conditions in counters/limits:** Read-then-write patterns on counters (SELECT count → UPDATE count+1) without SELECT FOR UPDATE, advisory lock, or atomic RPC. Common in: rate limiting, budget enforcement, badge/award granting. Severity: HIGH.
  - **Non-atomic multi-step transactions:** 2+ related DB writes (INSERT/UPDATE) without wrapping transaction (BEGIN/COMMIT, RPC, `.rpc('*_atomic*')`). Example: granting badge + updating counter as separate ops. Severity: HIGH.
  - **Logic bugs in authorization/business rules:** approver_id === requester_id (self-approval), giver_id === receiver_id (self-grant unless allowed), wrong column in WHERE for business intent. Severity: HIGH.
  - **Manager-by-role anti-pattern, cross-file (P14):** trace every authorization gate that says "is manager". For each, verify the implementation reaches `rpc('is_org_manager', ...)` or `departments.manager_id`/`teams.manager_id`. If a helper like `isAdminOrManager` is used, **read the helper definition** — Pass 1 may have only seen the call site. Flag (a) any helper whose body is `roles.includes('manager')` only, (b) inline role checks for manager-scope authorization, (c) **mixed pattern**: same PR has both canonical and role-based checks (this is a real MUST FIX even when defense-in-depth masks the bug downstream). Cross-check by grepping `is_org_manager` and `roles.includes('manager')` across all files of the PR. Severity: MUST FIX.
  - Issues that require reading 2+ files to detect

**Subagent B (cross-file frontend+i18n):** Only if Pass 1 flagged frontend or locale files.
- Input: Flagged frontend/locale files + Pass 1 i18n findings
- Focus:
  - Locale key parity: compare ES vs FR vs PT section by section
  - Frontend validation schema vs backend schema consistency

**Cost control:** Cap both subagents to the top 20 flagged files by severity.

After Pass 2, report:
```
Pass 2: Y findings (C:N H:N W:N S:N) — Opus, {M} files analyzed
Total: Z findings
```

---

### Step 3: Test Suite Review (conditional)

**Condition:** PR touches files in `supabase/functions/` (edge functions).

If applicable, invoke the `/pr-review-tests` skill logic:
- Auto-detect affected APIs from PR files
- Review doc compliance, coverage, duplicated logic, endpoint gaps
- Generate prioritized improvements

**Context from Pass 1+2:** Pass the findings summary so test review doesn't duplicate validation findings.

#### Step 3.1: CI Execution Verification (CRITICAL — always run when PR has test files)

**Why:** Test files that exist but are never executed by CI provide zero value and create a false sense of coverage. This check verifies that every test file in the PR is actually picked up by the CI pipeline's glob patterns.

1. Identify all test files in the PR (`*.test.ts`, `*.spec.ts`)
2. Fetch the CI workflow that runs tests:
```bash
gh api "repos/{repo}/contents/.github/workflows/backend-tests.yml?ref={branch}" --jq '.content' | base64 -d
```
3. Extract `deno test` glob patterns from the workflow (e.g., `supabase/functions/**/__tests__/unit/**/*.test.ts`)
4. For each test file in the PR, verify it matches at least one CI glob:
   - Parse the glob pattern segments (e.g., `__tests__/unit/` requires a `unit/` subdirectory)
   - Check the actual directory structure of each test file against the glob
5. **If ANY test file does NOT match any CI glob → MUST FIX (severity: CRITICAL)**
   - Report: file path, expected glob, actual path, suggested fix (move file or expand glob)

**Common mismatches to check:**
- Test in `__tests__/*.test.ts` but CI expects `__tests__/unit/**/*.test.ts` (missing subdirectory)
- Test in `__tests__/integration/` but CI only runs `__tests__/unit/`
- Test in `tests/` but CI looks in `supabase/tests/`
- Frontend test (`src/**/*.test.ts`) not included in any workflow

**Output format:**
```
CI Execution Check:
- X test files in PR
- Y matched by CI globs ✅
- Z NOT matched (MUST FIX) ❌
[table: file, expected pattern, actual path, fix]
```

---

### Step 4: Cross-Cutting Concerns

Invoke the `/pr-review-ccc` skill logic:
- Auto-detect affected modules (edge functions, _shared, migrations, frontend, locales)
- Run CCC checklist with 3 parallel agents (security+auth, architecture+points, frontend+i18n)
- Cross-section validation (auth-RLS coherence, feature flag coherence, i18n parity)
- **CI/CD coherence** (new edge functions in config.toml, new secrets in workflow, test files in CI globs)
- Report findings with MUST FIX / SHOULD FIX / CONSIDER

#### CI/CD Coherence Checklist (include in CCC agent prompt)
- [ ] **Test CI coverage:** If PR adds `*.test.ts` files, verify they match a `deno test` glob in `backend-tests.yml`. If not → MUST FIX.
- [ ] **Edge function registration:** If PR adds a new `supabase/functions/{name}/index.ts`, verify `[functions.{name}]` exists in `config.toml` with correct `verify_jwt` setting.
- [ ] **Secrets declared:** If PR code references `Deno.env.get('NEW_SECRET')`, verify the secret is mapped in `staging-deploy.yml` and `production-deploy.yml`.
- [ ] **Deploy includes function:** If PR adds a new edge function, verify the deploy workflow will pick it up (check for explicit function lists vs `--prune` flag).
- [ ] **Cron direct-sql → preview adapter:** If PR adds a `cron.schedule` with body `SELECT public.<fn>()` (direct-sql), verify `supabase/functions/cron-direct/index.ts` is modified in the same PR with the action added to `ALLOWED_ACTIONS` and a test added in `cron-direct/__tests__/unit/handler.test.ts`. If not → MUST FIX (cron works in prod via pg_cron+pg_net but breaks silently in preview Cloud Scheduler).
- [ ] **Cron canonical parser:** If PR adds/modifies migrations with `cron.schedule`, verify the parser (`scripts/extract-cron-manifest.ts`) would still report 0 non-canonical. Use the canonical format from `docs/cron-canonical-format.md` as the spec.
- [ ] **Feature flag default in same PR:** If PR introduces a new flag key in code (`is_feature_enabled(_, 'new_key')` or middleware call), verify a migration in the SAME PR has `INSERT INTO feature_flag_defaults` (or equivalent seed) for that key. Missing = MUST FIX (fail-closed means feature dead-on-arrival in production).

**Context from Pass 1+2:** Include findings summary as preamble:
> "El análisis automatizado (Pass 1+2) ya identificó estos issues: {summary}. Enfócate en áreas NO cubiertas. NO re-reportes issues ya identificados."

---

### Step 5: Scope Discipline (if >20 files)

Unless `--skip-scope` or PR has ≤20 files:
- Classify files: IN-SCOPE / RELATED-RISKY / OUT-OF-SCOPE / INCOMPLETE
- Report scope score (1-10) and out-of-scope findings

> **Lente de producto (puntero, no pipeline):** este review es TÉCNICO (seguridad / scope / tests). El lente de PRODUCTO de un cambio no vive acá — vive en `/product-lens` (propuestas) y en el kernel K1-K6 del Product Decision Canon que corre el gate del flujo linear (B2 de `_shared/linear-contract.md`). Si en el scope audit un OUT-OF-SCOPE tiene implicación de producto (toca un outcome, deja a un actor invisible → K1/K4 del canon), repórtalo como **insumo para el dueño del scope**, nunca como veredicto de alcance. No corras el kernel completo en cada PR; es ruido fuera de propuestas.

---

### Step 5.5: Manager Logic Audit (conditional, run aggressively)

**Trigger condition (ANY of):**
- PR touches edge functions that reference `manager_id`, `departments`, `teams`, or auth/permissions files (`*/utils/auth.ts`, `_shared/*-auth.ts`, `_shared/auth-utils.ts`, `_shared/rbac*.ts`).
- PR diff contains any of these strings (run `gh pr diff {prNumber} -R {repo} | grep -E ...` once before deciding to skip):
  - `isAdminOrManager`, `isManager`, `requireManager`, `assertManager`
  - `roles.includes('manager')`, `roles.includes(\"manager\")`
  - `userRole.role === 'manager'`, `userRole.role == 'manager'`
  - `['admin', 'manager'`, `["admin", "manager"`
  - `is_org_manager` (canonical — also worth auditing to confirm consistency)
- PR touches `users/index.ts` (the central recognitions feed has historically reproduced the anti-pattern inline).

**Don't skip lightly.** This audit is cheap (one agent, ~30s) and the failure mode (mixed pattern across the same PR) is invisible to Pass 1/2 because each file looks fine in isolation.

If applicable, invoke the `/pr-review-audit` skill logic:
- Auto-detect affected APIs
- Audit manager determination patterns (correct: `is_org_manager` RPC or `departments.manager_id` / `teams.manager_id`; wrong: `roles.includes('manager')`, `userRole.role === 'manager'`, `isAdminOrManager` helper backed only by role string)
- **Mixed pattern detection:** grep across the entire PR for both `is_org_manager` AND `roles.includes('manager')`. If both appear, this is an automatic MUST FIX in the report (the gate is semantically inconsistent even if defense-in-depth masks the bug)
- Recommend creating `_shared/org-manager.ts` helper if absent (skeleton in `pr-review-audit/SKILL.md` paso 9)
- Classify each finding as correct/wrong/needs_review

---

### Step 6: FP Validation (precision self-check)

Validate all agent analysis findings (Pass 1 + Pass 2) against the actual code to classify as TP/FP/NEEDS_REVIEW.

Launch 1 Agent (model: "haiku") with:
- All findings from Pass 1 + Pass 2
- The FP heuristics below

**FP Heuristics to apply per finding:**

| ID | Heuristic | If true → |
|----|-----------|-----------|
| S4 | tenantId is server-derived (from `c.get('auth')`, `user_roles`, or internal `_shared/` caller) | FP |
| S6 | Global middleware in `index.ts` already covers the flagged route (`app.use('*', ...)`) | FP |
| S8 | Finding targets `/health`, `/healthz`, `/status`, `/ping` | FP |
| I5 | "High complexity" on normal React hook / route handler pattern | FP |
| I8 | Finding targets generated types file (`types.ts`, auto-generated) | FP |
| BE | Backend API validation message in English (Zod in edge function, not `.tsx`) | FP |

**Agent prompt:**
```
You are verifying {N} findings from PR #{prNumber} for false positives.

For each finding:
1. Fetch the file via: gh api "repos/{repo}/contents/{file}?ref={branch}" --jq '.content' | base64 -d
2. Locate the line referenced
3. Apply each heuristic — if ANY matches, classify as FP with evidence
4. If no heuristic matches and the issue is real, classify as TP
5. If unclear, classify as NEEDS_REVIEW

Output: table with columns: #, File, Severity, Classification (TP/FP/NR), Heuristic (if FP), Evidence (one line)
Summary: X TP, Y FP, Z NR. Precision: X/(X+Y)%.
```

After validation:
- Remove FP findings from the final report (mark them as `[FP — removed]`)
- Log precision metric

---

### Step 6.5: Quick Wins

Analyze all MUST FIX and SHOULD FIX findings. Identify those requiring **less than 5 minutes**:
- `git rm` of a debug artifact or incorrect lockfile
- Changing a string literal to an i18n key **that already exists** in locales
- Changing `TO public` → `TO service_role` in an RLS policy
- Removing a custom Zod message and using the default
- Adding a JSDoc header copying the pattern from neighboring files
- Removing `console.log` statements

Present as table: #, Action, File, Estimated Time, Detail.

---

### Step 7: Output Final

**ALL output MUST be in neutral Latin American Spanish.** Do not wait for the user to request it.

Output the text report to the conversation:

```
## Reporte de Revisión — PR #{prNumber}

**Feature:** {título del PR}
**Stats:** {additions} adiciones, {deletions} eliminaciones, {changedFiles} archivos

---

### 1. Análisis Automatizado (2-Pass)
- Pass 1 (Haiku): X findings (C:N H:N W:N S:N) — {N} archivos analizados
- Pass 2 (Opus): Y findings (C:N H:N W:N S:N) — {M} archivos analizados
- Total: Z findings

### 2. Cross-Cutting Concerns
MUST FIX (N bloqueantes):
[tabla con #, archivo, línea, problema]

SHOULD FIX (N):
[tabla o lista agrupada por categoría]

CONSIDER (N):
[tabla o lista]

Buenas prácticas (N):
[lista de patrones positivos encontrados]

### 3. Revisión de Tests (si aplica)
[tabla de APIs con conteo de tests + gaps priorizados]

### 4. Manager Audit (si aplica)
[tabla de APIs con patrones correct/wrong]

### 5. Disciplina de Scope (si aplica)
- Score: X/10
- [tabla de clasificación]

### 6. Validación de Precisión
- Findings validados: X TP, Y FP removidos, Z needs review
- Precisión: X/(X+Y)%
[tabla de FPs removidos si hay, con heurística aplicada]

### 7. Quick Wins (hacer antes de merge)
[tabla con #, acción, archivo, tiempo estimado, detalle]
Tiempo total estimado: ~N minutos

### 8. Superficie reviewada (Iteration Contract — Regla 3)
| Status | Archivos / áreas |
|--------|-------------------|
| ✅ Auditado | <archivos revisados a profundidad en esta iter> |
| ⚠️ Spot-check | <archivos vistos en pasada superficial> |
| ❌ No auditado | <archivos del PR que NO se revisaron> |

### 9. Clasificación de origen (solo en iter N≥2)
Por cada finding nuevo en esta iter, etiqueta de origen + ¿bloquea?:

| # | Finding | Tag | ¿En delta {prev_sha}..{curr_sha}? | ¿Bloquea? |
|---|---------|-----|------------------------------------|-----------|
| ... | ... | REGRESSION/CARRY-OVER/PRODUCT_CLARIFICATION/DEPTH/SCOPE_EXPANSION | sí/no | sí/no |

DEPTH y SCOPE_EXPANSION NO bloquean — van a tickets de deuda independientes.

### 10. Estado de salida (Iteration Contract — Regla 5)
Estado: **READY TO MERGE** / **APPROVE WITH CONDITIONS** / **BLOCK**

**Bar del trunk:** <P0/P1 | MUST-FIX-or-above | etc> (declarado por owner | default).

Si APPROVE WITH CONDITIONS:
- Conditions (lista cerrada, exactas):
  1. <condition + archivo + criterio de verificación objetivo>
  2. ...
- Compromiso: si las conditions se cierran, iter N+1 = READY salvo REGRESSION / CARRY-OVER / PRODUCT_CLARIFICATION nuevos. NO se añadirán bloqueantes por DEPTH ni SCOPE_EXPANSION.

Si BLOCK (escalación iter 3):
- Razón estructural: <PR demasiado grande | spec ambiguo | mixed pattern | ...>
- Stakeholders requeridos en meeting: <owner | tech lead | dev | producto>

Tickets de deuda a crear (DEPTH/SCOPE_EXPANSION/CARRY-OVER sin defensa):
- <tag de origen | archivo | breve descripción>
```

**Save report as .md file** in the vault, organized by project and repository (NOT in the repo cwd, NOT in the vault root `reviews/` — retired path):
```bash
Write file: ~/Code/_vault/_work/apprecio/projects/{project}/reviews/{repo}/pr{prNumber}-review-report.md
# project from repo: apprecio-pulse / ryr-39255 → rr. If the review belongs to a
# specific Linear issue, prefer the issue folder: projects/{project}/issues/{ISSUE-ID}/
```

---

## Language Rules

- **ALL** conversational output and final report MUST be in **neutral Latin American Spanish**
- File names, variables, and code stay in English (they are code)
- Severities stay in English: MUST FIX, SHOULD FIX, CONSIDER, BLOCK
- API error messages are reported as-is from the code (do not translate)

## Notes

- `{repo}` se autodetecta desde el git remote del cwd. Override con `--repo owner/repo`.
- The manager audit (`/pr-review-audit`) runs automatically when the PR touches manager/department/team files
- `--skip-agent` skips Steps 1-2 (both passes) — only manual review runs
- `--skip-scope` skips Step 5
- The full set of acceptable patterns (anti-FP rules) lives in `knowledge/acceptable-patterns.md` of this repo
- **The Iteration Contract** — rules for when to approve, when to block, and how many iters are allowed — lives in `knowledge/iteration-contract.md`. **Apply it in every iter:** Step 0 detects previous iter and computes delta; Step 7 sections 8–10 enforce surface declaration, origin classification, and explicit exit state. DEPTH and SCOPE_EXPANSION findings NEVER block merge — they go to deuda tickets. Iter 3 is the hard stop before escalation to meeting.
- **Domain detection-rules** — positive detection rules specific to product domain (e.g., economic grants governance, future rules for notifications/cron/shared-modules) live in `knowledge/detection-rules/`. Index in `knowledge/detection-rules/README.md`. Each rule declares its own **Trigger** (file patterns / symbols that activate it) and **Skills que la consumen** (which subagent should load it). Step 2.6 evaluates triggers against the PR and conditionally injects matched rules into subagent prompts. To add a new rule, follow the template in the README and update the rules table.
