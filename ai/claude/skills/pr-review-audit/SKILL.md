---
name: pr-review-audit
description: Audit "who is manager" logic across ALL edge functions in a PR. Auto-detects which APIs are touched and checks that manager determination uses departments.manager_id / teams.manager_id, not profiles + role inference.
---

# Manager Logic Audit

**Usage:** `/pr-review-audit {prNumber}` or `/pr-review-audit {prNumber} --repo owner/repo`

## Instructions

1. Parse the PR number. **Resolve `{repo}`** in this order: (1) `--repo owner/repo` if passed; (2) auto-detect via `gh repo view --json nameWithOwner -q .nameWithOwner` from cwd; (3) if both fail, ask the user and stop.

2. Get the list of changed files in the PR:
```bash
gh api repos/{repo}/pulls/{prNumber}/files --paginate --jq '.[].filename'
```

3. **Auto-detect affected APIs.** From the changed files, identify:
   - **Direct API changes:** Edge functions under `supabase/functions/*/` — extract the function name (e.g., `supabase/functions/challenge-api/...` → `challenge-api`).
   - **Shared module changes:** Files under `supabase/functions/_shared/` — trace which edge functions import them:
     ```bash
     # For each changed _shared module, find which functions import it
     gh api repos/{repo}/contents/supabase/functions?ref={headSha} --jq '.[].name'
     # Then check imports in each function's entrypoint
     ```
   - **Migration changes:** SQL files under `supabase/migrations/` that create/alter functions, views, or RLS policies involving manager/department/team logic.

   Build a list of **all affected APIs** (edge functions) that need auditing.

4. **For each affected API**, identify in-scope files:
   - The API's own files (`supabase/functions/{api-name}/`)
   - Any `_shared/` modules imported by that API
   - Focus on files that touch manager/department/team/permissions logic

   To resolve imports:
   ```bash
   # Get the API's entrypoint and route files
   gh api repos/{repo}/contents/supabase/functions/{api-name}?ref={headSha} --jq '.[].name'
   # Scan imports to _shared
   # Read files that reference manager, department, team, role, permission, scope
   ```

5. **If multiple APIs are affected, launch parallel agents** — one per API (max 4 concurrent). Each agent audits one API against the checklist below.

### Canonical source of truth

The project ships a Postgres function `public.is_org_manager(_user_id UUID, _tenant_id UUID)` (introduced in migration `20260206152933_*.sql`). It returns `true` iff the user is `manager_id` of any `departments` or `teams` row in that tenant. This is the **single canonical check** for "is this user a manager".

Verified canonical consumers in the repo (do NOT flag):
- `awards-api/utils/auth.ts`
- `challenge-api/index.ts`
- `recognition-api/services/grant.service.ts` (used by `validateAudienceScope`)
- `recognition-api/routes/audit-timeline.ts`, `routes/moderation.ts`
- `recognition-api/services/recognition-types-public-service.ts`
- `awards-api/services/public.service.ts`, `services/nominations.service.ts`
- `generate-award-cycles/index.ts`
- `src/contexts/AuthContext.tsx` (frontend)

There is even an existing security test that enforces this: `supabase/functions/challenge-api/__tests__/unit/security/org-manager-authorization.security.test.ts` whose assertion message is:
> "Authorization must use is_org_manager RPC, not role string."

**Helper gap (worth surfacing in every report):** as of this writing the project does **not** export a TypeScript wrapper from `supabase/functions/_shared/`. Each call site invokes `supabase.rpc('is_org_manager', { _user_id, _tenant_id })` directly. That's why drift keeps creeping in (e.g. `admin-api/utils/auth.ts::isAdminOrManager` never adopted the RPC and propagated role-based checks to `recognition-api/routes/spot-reward.ts` and `users/index.ts`). When you find the anti-pattern below, **also recommend** creating `supabase/functions/_shared/org-manager.ts` with a thin wrapper such as `isOrgManager(supabase, userId, tenantId)` so the dev does not have to re-implement the rule.

6. For each in-scope file that touches manager/department/team/permissions, check for these **WRONG** patterns:

   - **`isAdminOrManager` (or equivalent) backed by role string only:** any helper that returns `true` because `ctx.roles.includes('manager')`, `userRole.role === 'manager'`, or `['admin', 'manager', 'hr'].includes(role)` **without** calling `is_org_manager` RPC or querying `departments.manager_id` / `teams.manager_id` for the same user.
     - Frequent location: `*/utils/auth.ts`, `_shared/*-auth.ts`. Trace every call site of the helper — the fix has to be at the helper, not at each call site.
     - This is the most common manifestation. Always grep for `isAdminOrManager`, `isManager`, `requireManager`, `assertManager` and verify the implementation reads `manager_id` / `is_org_manager` somewhere on the path.
   - **Inline role check for manager-scope authorization:** `if (userRole.role === 'manager')`, `if (roles.includes('manager'))`, `['admin','manager','hr'].includes(role)` used as a gate (visibility, mutation rights, audience scope) without an `is_org_manager` lookup.
   - **Role + profile org only:** Treating user as manager because `user_roles.role = 'manager'` AND `profiles.department_id` matches, WITHOUT checking `departments.manager_id` or `teams.manager_id`.
   - **Querying "managers in department":** `SELECT users WHERE role = 'manager' AND profiles.department_id = X` instead of `departments WHERE manager_id = user_id`.
   - **Scope by profile:** Granting manager permission based on `user_roles.role` + `profiles.department_id` instead of `departments.manager_id` / `is_org_manager` RPC.
   - **Listing "my units":** Building managed units list from profile fields instead of `departments/teams WHERE manager_id = current_user_id`.
   - **Hardcoded role check for manager scope:** Using `role === 'manager'` to determine what data a user can see/edit, instead of querying which departments/teams have `manager_id = user_id`.
   - **Missing tenant scoping on manager queries:** Manager lookups via `departments.manager_id` that don't also filter by `tenant_id`.
   - **Mixed pattern within the same handler:** the SAME route uses `is_org_manager` / `departments.manager_id` in one step and `roles.includes('manager')` in another. This is an automatic MUST FIX — it means the gate is semantically wrong even when defense-in-depth happens to mask it (e.g. Step 4 lets a role-legacy "manager" through and Step 7 only later denies via `OUT_OF_AUDIENCE_SCOPE`).

7. **CORRECT** patterns (do not flag):
   - `departments.manager_id` / `teams.manager_id` (with `tenant_id` filter)
   - `rpc('is_org_manager', { _user_id, _tenant_id })`
   - `rpc('has_role', ...)` for admin check (not manager scope)
   - Reading `profiles.department_id` for **collaborator membership** (not manager status)
   - `validateManagerScope` / `validateAudienceScope` utility that internally uses `departments.manager_id` / `teams.manager_id` / `is_org_manager`

8. For each finding:
   - **API:** which edge function
   - **File:Line:** exact location
   - **Pattern:** quote the exact logic
   - **Classification:** CORRECT or WRONG
   - If WRONG: one-sentence summary + what the correct logic should be

9. **Always include a "Helper recommendation" section** after the per-API tables. If `supabase/functions/_shared/org-manager.ts` does not exist, propose its skeleton:

```ts
// supabase/functions/_shared/org-manager.ts
import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Canonical "is this user an org manager?" check.
 * Wraps the public.is_org_manager(_user_id, _tenant_id) Postgres function
 * (migration 20260206152933) so callers do not re-implement the rule.
 *
 * Use this everywhere instead of `roles.includes('manager')`.
 */
export async function isOrgManager(
  supabase: SupabaseClient,
  userId: string,
  tenantId: string,
): Promise<boolean> {
  const { data, error } = await supabase.rpc('is_org_manager', {
    _user_id: userId,
    _tenant_id: tenantId,
  });
  if (error) {
    console.error('[org-manager] is_org_manager RPC error:', error.message);
    return false; // fail-closed
  }
  return data === true;
}

export async function isAdminOrOrgManager(
  supabase: SupabaseClient,
  userId: string,
  tenantId: string,
  roles: string[],
): Promise<boolean> {
  if (roles.includes('admin')) return true;
  return await isOrgManager(supabase, userId, tenantId);
}
```

Recommend that the dev migrate `*/utils/auth.ts::isAdminOrManager` (and any inline `roles.includes('manager')`) to use this helper. Once the helper exists, the FP rate of this audit drops to ~0 because grepping for `roles.includes('manager')` becomes a binary lint.

10. End with summary per API and overall:
```
## Per-API Results
- challenge-api: X files, Y correct, Z wrong
- training-api: X files, Y correct, Z wrong
- ...

## Helper status
- `_shared/org-manager.ts` exists: yes / no
- Call sites still using role string: N

## Overall
Audit: N APIs audited, X total files checked, Y correct patterns, Z wrong patterns.
```

## Idioma

TODO el output debe ser en **español neutro latinoamericano**. Nombres de archivos, variables y código se mantienen en inglés. Severidades en inglés (MUST FIX, SHOULD FIX, CONSIDER).
