---
name: pr-review-scope
description: Scope discipline audit for a PR. Classifies files as in-scope, related-but-risky, out-of-scope, or incomplete-scope using codebase module architecture knowledge.
---

# Scope Discipline Audit

**Usage:** `/pr-review-scope {prNumber}` or `/pr-review-scope {prNumber} --repo owner/repo`

## Step 1: Gather PR Context

1a. Parse PR number. **Resolve `{repo}`** in this order: (1) `--repo owner/repo` if passed; (2) auto-detect via `gh repo view --json nameWithOwner -q .nameWithOwner` from cwd; (3) if both fail, ask the user and stop.

1b. Get PR intent:
```bash
gh pr view {prNumber} -R {repo} --json title,body --jq '{title,body: .body[0:800]}'
```

1c. Get changed files with stats:
```bash
gh api repos/{repo}/pulls/{prNumber}/files --paginate --jq '.[] | {filename, status, additions, deletions, changes}'
```

1d. Extract the PR's **declared objective** from title + body. Summarize in 1 sentence. This is the scope boundary.

## Step 2: Module Architecture Map

Use this knowledge of the apprecio-pulse structure to classify files:

### High-Impact Zones (changes here affect many modules)

| Zone | Path Pattern | Impact |
|------|-------------|--------|
| Shared modules | `supabase/functions/_shared/*` | Imported by ALL edge functions. Any change must be evaluated against all importers. |
| Migrations | `supabase/migrations/*` | Schema changes affect all APIs that query the modified tables. |
| Locales | `src/locales/*` | Must stay in sync across en/es/fr/pt. |
| Shared frontend | `src/lib/*` | Auth, API clients, types — used across all frontend modules. |
| Config | `config.toml`, `package.json`, `tsconfig.json` | Affects build/deploy for entire project. |

### Module Boundaries (files expected to change together)

| When this changes... | ...these should also change |
|---------------------|-----------------------------|
| `supabase/functions/{api}/routes/*` | `supabase/functions/{api}/services/*`, `supabase/functions/{api}/__tests__/*` |
| `supabase/migrations/*` (new table/column) | Corresponding edge function queries + types |
| `supabase/migrations/*` (RLS policy) | Auth middleware in affected edge functions |
| `src/modules/{module}/*` | `src/hooks/use{Module}*`, `src/locales/*/` |
| `supabase/functions/_shared/*` | Any edge function that imports the changed module |

### Cross-Cutting Dependency Rules

1. **_shared module impact:** If `_shared/recognition-service.ts` changes, all APIs using `grantRecognitionInternal` are affected. If `_shared/economic-grant-utils.ts` changes, that's scope creep unless the PR is explicitly about grant refactoring.
2. **Migration-auth coherence:** RLS policy changes need corresponding auth middleware changes in edge functions.
3. **Tridimensional model:** XP/Economic/Recognition grant changes in one API may need parity changes in others.
4. **Locale parity:** Adding keys to one locale file without the other 3 (en/es/fr/pt) is incomplete scope.
5. **Test coherence:** Production code changes without corresponding test changes are incomplete (not out-of-scope, but missing companions).

## Step 3: Classify Each File

For each changed file, classify into one of 4 categories:

### IN-SCOPE
Directly related to the PR's declared objective. No action needed.

### RELATED-BUT-RISKY
Touches shared infrastructure that could break other modules. Sub-classify by risk:

| Risk | Criteria | Examples |
|------|----------|---------|
| **HIGH** | _shared module changes, RLS policy changes, tridimensional model changes | `_shared/recognition-service.ts`, `migrations/*_rls_*` |
| **MEDIUM** | Migration changes to tables used by other APIs, locale additions without parity | `migrations/*_add_column_*`, `locales/en/training.json` (without es/fr/pt) |
| **LOW** | Type definition updates, config changes, shared utility tweaks | `_shared/types.ts`, `config.toml` |

### OUT-OF-SCOPE
No connection to the PR's declared objective. Sub-classify:

| Type | Description |
|------|-------------|
| **Cosmetic** | Formatting, whitespace, import ordering, comment typos |
| **Refactor** | Renaming, restructuring without behavior change |
| **Unrelated feature** | New functionality for a different issue |
| **Opportunistic fix** | Bug fix for a different problem |

### INCOMPLETE-SCOPE
The PR changes production code but is missing expected companion changes:

| What Changed | What's Missing | Signal |
|-------------|---------------|--------|
| Production code | No test changes | Route/service changed but no `__tests__/` file touched |
| Migration (new table/column) | No API update | Schema exists but no edge function queries it |
| Backend endpoint | No frontend integration | API added but no hook/component uses it |
| Locale key in 1 language | Other 3 languages missing | Only `en.json` updated, not `es/fr/pt` |
| Edge function route | No e2e test | New endpoint but no `tests/e2e/` coverage |

## Step 4: Parallelization (if >30 files)

If the PR has more than 30 changed files, launch **2 agents in parallel**:

- **Agent 1 — Backend:** Files under `supabase/functions/*`, `supabase/migrations/*`, config files. Classify against PR objective using the module architecture map.
- **Agent 2 — Frontend:** Files under `src/*`, `public/*`, locale files. Classify against PR objective.

Each agent must read the PR title and body before classifying. Give each agent the full classification framework above.

If ≤30 files, classify all files in a single pass (no agents needed).

## Hard Guardrails

- **Read PR body first.** The body often explains why seemingly unrelated changes are included ("also addressed X in this PR"). Do NOT flag those as out-of-scope.
- **Do NOT flag test files** as out-of-scope if they test code changed in the PR.
- **Do NOT flag _shared modules** as out-of-scope if the PR's target API imports them. Trace imports first.
- **Do NOT flag migrations** as out-of-scope if they add/alter tables that the PR's changed code queries.
- **Gray zone check:** If a file's classification is unclear, check `gh api repos/{repo}/pulls/{prNumber}/files --jq '.[] | select(.filename == "FILE") | .patch'` to see what actually changed. A 1-line import change is different from a 50-line refactor.
- **Do NOT invent problems.** Only flag things with concrete evidence from the file list and diff.

## Step 5: Module Dependency Check

After classification, run these specific checks:

1. **_shared importers:** For each changed `_shared/*` file, identify which edge functions import it:
   ```bash
   gh api repos/{repo}/contents/supabase/functions?ref={headSha} --jq '.[].name' | while read fn; do
     # Check if function imports the changed _shared module
   done
   ```
   Report: `"{module} imported by: {api-1}, {api-2}, {api-3}"`

2. **Migration cross-API impact:** For each changed migration, extract table names and identify which APIs query those tables.

3. **Locale parity:** If any locale file changed, check all 4 locales for the same keys:
   ```bash
   gh pr diff {prNumber} -R {repo} -- 'src/locales/*' | grep '^+.*"' | # extract added keys
   ```

## Step 6: Output Format

```
## PR #{prNumber} Scope Discipline Audit

### PR Objective
- **Title:** {title}
- **Declared scope:** {1-sentence summary from body}
- **Files changed:** {N}

### A) Classification Summary
| Classification | Count | % of Total |
|----------------|-------|------------|
| In-Scope       |       |            |
| Related-But-Risky |    |            |
| Out-of-Scope   |       |            |
| Incomplete-Scope |     |            |

### B) Related-But-Risky Changes
| # | File | Risk | Impact Radius | Recommendation |
|---|------|------|---------------|----------------|

### C) Out-of-Scope Changes
| # | File | Type | Lines Changed | Should Split? | Risk |
|---|------|------|---------------|---------------|------|

### D) Incomplete Scope (Missing Companions)
| # | What Changed | What's Missing | Why It Matters |
|---|-------------|---------------|----------------|

### E) Module Dependency Check
- _shared modules changed: {list with importer count}
- Migrations with cross-API impact: {list with affected APIs}
- Locale parity: {OK / MISSING for specific languages}

Scope discipline score: X/10
PRs likely packaged: N
Risk: Low / Medium / High

Standard: {N} files analyzed, {X} in-scope, {Y} related-but-risky, {Z} out-of-scope, {W} incomplete. Score: {S}/10.
```

## Scoring Guide

| Score | Criteria |
|-------|----------|
| **9-10** | All files in-scope, no missing companions, clean module boundaries |
| **7-8** | Minor related-but-risky changes or 1-2 cosmetic out-of-scope files |
| **5-6** | Multiple out-of-scope files or missing test companions |
| **3-4** | Significant scope creep — 2+ unrelated features mixed in |
| **1-2** | Multiple PRs packaged into one — recommend splitting before merge |

## Thresholds

- **>20 files changed:** Always run scope audit
- **≤20 files:** Skip unless explicitly requested
- **Score 8-10:** Clean scope, no action needed
- **Score 5-7:** Suggest splitting for next time
- **Score 1-4:** Recommend splitting before merge

## Idioma

TODO el output debe ser en **español neutro latinoamericano**. Nombres de archivos, variables y código se mantienen en inglés. Severidades en inglés (MUST FIX, SHOULD FIX, CONSIDER).

