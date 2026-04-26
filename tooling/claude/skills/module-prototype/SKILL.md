---
name: module-prototype
description: >
  Generate or improve a UI prototype from Module Design + PRD.
  Creates working React prototypes with mock data for both Backoffice and App.
  Trigger: When the orchestrator launches you to create or improve a prototype.
license: MIT
metadata:
  author: cesar-moreno
  version: "1.0"
---

## Purpose

You are a sub-agent responsible for MODULE PROTOTYPE. You take a Module Design Document (MDD) and PRD, then generate a fully functional UI prototype with mock data — no backend, no API calls. The prototype is the visual implementation of the MDD that can be demo'd, tested, and later evolved into the real implementation by replacing mock queryFn with API calls.

## What You Receive

From the orchestrator:
- Change name (e.g., "registro-fotografico")
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `module-prototype`. Retrieve `prd`, `module-design` as dependencies.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`.
- If mode is `none`: Return result only.

### Retrieving Dependencies

**Required:**
- `sdd/{change-name}/module-design` — The MDD with wireframes, component inventory, data model (REQUIRED — abort if missing)
- `sdd/{change-name}/prd` — The PRD with user stories, ACs, edge cases, business rules (REQUIRED — abort if missing)

**Optional:**
- `sdd/{change-name}/prd-review` — Review report (if exists, use to verify no critical gaps)

### Mode Detection

This skill has TWO modes with smart detection:
- **CREATE**: When prototype files don't exist in the codebase → generate from scratch
- **EDIT**: When prototype files already exist → audit against PRD, report gaps, improve

Detection: Search for the module's component directory (e.g., `src/components/{module-name}/`). If it exists with >3 files, mode is EDIT. Otherwise, CREATE.

## What to Do

### Mode: CREATE

#### Step 1: Read Dependencies

1. Retrieve MDD from Engram (wireframes, component inventory, data binding map)
2. Retrieve PRD from Engram (user stories with GIVEN/WHEN/THEN ACs, edge cases, business rules, product decisions)
3. If MDD was split across multiple Engram observations, retrieve all parts

#### Step 2: Read Codebase Patterns

MANDATORY before generating. Read the actual codebase:

```
SCAN:
├── src/pages/             → page structure, routing, tab patterns
├── src/components/        → component organization, naming conventions
├── src/hooks/             → React Query patterns (query keys, staleTime, mutations)
├── src/types/             → existing type conventions
├── src/App.tsx            → routing configuration
├── package.json           → available dependencies (UI library, icons, etc.)
└── Navigation/Sidebar     → how to add module entry point
```

#### Step 3: Generate Shared Foundation (SINGLE AGENT — never parallelize this)

Create these files FIRST, before any UI components:

1. **Types** (`src/types/{module-name}.ts`)
   - All domain types from MDD Data Model section
   - Include ALL fields needed by BOTH platforms (BO + App)
   - Include filter types, config types, export types
   - Include IA-related fields even if not visible in all screens

2. **Mocks** (`src/mocks/{module-name}.ts`)
   - Realistic mock data covering ALL states from PRD
   - Enough variety to demo every filter, badge, and edge case
   - Include mock data for: main entities, config, dashboard KPIs, audit logs, notifications, tasks
   - Use realistic names (match locale), dates, GPS coords
   - Include items that trigger edge cases (out of range, duplicates, sync failed, expired)

3. **Hooks** (`src/hooks/{module-name}/`)
   - One file per domain area (e.g., useEvidencias, useDashboard, useConfig, useExport)
   - Follow project's React Query pattern (query key factory, staleTime, gcTime)
   - Mutations use setTimeout to simulate API delay
   - In-memory state mutation so UI reflects changes during demo
   - Include ALL mutations from PRD (approve, reject, bulk approve, bulk reject with comment, mark as read, retry sync, etc.)

#### Step 4: Generate UI Components (CAN parallelize BO + App)

Now that types/mocks/hooks are shared, generate UI in parallel:

**For each platform (Backoffice / App):**

1. Read the MDD wireframes for that platform's screens
2. Create components following project patterns (shadcn/ui, Tailwind, lucide-react)
3. Create the main page with routing/navigation
4. Add module entry point (sidebar item, dashboard card, route in App.tsx)

**Rules for component generation:**
- Import types from shared `@/types/{module-name}` — NEVER create platform-specific types
- Import hooks from shared `@/hooks/{module-name}/` — NEVER create platform-specific hooks
- Use real component names from project's UI library (shadcn/ui)
- Use real field names from types (not lorem ipsum)
- Make interactions functional (filters filter, modals open/close, forms validate)
- Bypass ModuleGuard for prototype (add TODO comment for re-enabling)

#### Step 4.5: UX Polish (auto-detected, applies to both platforms)

After generating components, apply UX polish based on what the project supports. This step is AUTOMATIC — it reads the project's existing design tokens and dependencies, then applies them. No hardcoded brand values.

**Detection phase — read the project:**
1. Read `src/index.css` (or main CSS file) for CSS variables (`--primary`, `--gradient-*`, `--shadow-*`, `--radius`, etc.)
2. Read `package.json` for animation libraries (`framer-motion`, etc.)
3. Read `tailwind.config.ts` for custom theme extensions
4. Read 2-3 existing polished screens in the project to understand the visual standard

**Universal rules (BOTH platforms):**
- Skeleton loaders instead of generic spinners — use Skeleton component from shadcn/ui for all loading states
- Empty states with large icon (h-16 w-16) + descriptive heading + actionable CTA button (not just text)
- Typography hierarchy: clear distinction between headings (text-lg font-semibold), body (text-sm), metadata (text-xs text-muted-foreground)
- Consistent spacing: follow the project's padding/gap pattern (read from existing components)
- Status indicators using project's semantic colors (--success, --warning, --destructive) if defined
- Hover feedback on ALL clickable elements (at minimum: `hover:bg-muted/50 transition-colors`)
- Avatars at readable size (h-8 w-8 minimum) with fallback initials

**App-specific rules (mobile-first platforms):**
- Touch targets minimum 44px (h-11) on all interactive elements
- Primary CTA buttons use project's gradient if `--gradient-primary` exists in CSS, otherwise use solid primary
- Cards use `--shadow-soft` or equivalent if project defines custom shadows
- Hover scale: `hover:scale-105 transition-all duration-300` on cards and tiles
- If framer-motion available: add subtle page transitions (fade 200ms) between screens
- Soft backgrounds: use `--primary-soft` or `--accent` for highlighted cards if tokens exist
- Avatar rings: `ring-2 ring-primary/20` if the project's existing screens use this pattern

**Backoffice-specific rules (desktop-first platforms):**
- Data density: tables are fine — don't replace with cards. But ensure row hover states and adequate padding
- Hover feedback: `hover:bg-muted/50` on table rows, `hover:shadow-md` on cards
- Filter sections: clear visual separation from content (border-b or bg-muted background)
- Action buttons: primary actions use solid primary color, destructive actions use --destructive
- Modal/Dialog content: consistent padding (p-6), clear section separation with Separator components
- Dashboard KPI cards: use subtle colored backgrounds per metric category if project defines color tokens

**How to apply:**
- Do NOT create new CSS classes or modify index.css
- Use Tailwind classes that reference CSS variables: `bg-primary`, `text-primary-foreground`, `shadow-primary`
- If a token doesn't exist, use shadcn defaults (don't invent values)
- Read the project's existing screens as the visual standard — match their level of polish, don't exceed it

#### Step 5: Implement Behaviors (CRITICAL — this is where CREATE mode usually fails)

After screens are generated, verify and implement these cross-cutting behaviors from the PRD:

**Check each PRD section:**

1. **User Stories ACs** — For each GIVEN/WHEN/THEN:
   - Can this scenario be executed in the prototype?
   - If not, implement the missing behavior

2. **Edge Cases** — For each edge case:
   - Is there a UI state that shows this scenario?
   - If not, add it (e.g., empty states, error states, warning dialogs)

3. **Business Rules** — For each rule:
   - Is it enforced in the UI? (e.g., min 10 chars for rejection, max 5 photos)
   - If not, add the validation

4. **Product Decisions** — For each decision:
   - Is the chosen behavior reflected? (e.g., "never blocks" means no blocking modals for geo)

**Common behaviors to verify:**
- Bulk reject: must prompt for motivo with min 10 chars validation
- Logout with pending: must show warning modal
- Notifications: must mark as read on interaction
- Filters: must be shared via URL params or context (not local state)
- Duplicate detection: must show score + soft warning in both BO and App

#### Step 6: TypeScript Verification

Run the project's TypeScript checker:

```bash
./node_modules/.bin/tsc --noEmit -p tsconfig.app.json
```

If errors exist, fix them. Do NOT skip this step.

#### Step 7: Commit and Push

Stage, commit, and push the prototype:

```
git add src/types/{module} src/mocks/{module} src/hooks/{module} src/components/{module} src/pages/{Module}.tsx src/App.tsx
git commit -m "feat: add {Module} prototype (mock data)"
git push
```

#### Step 8: Audit Against PRD

Before reporting "done", run this audit:

```
For each User Story in PRD:
  1. Identify the component(s) that implement it
  2. Check each AC (GIVEN/WHEN/THEN) can be executed
  3. Score: PASS / PARTIAL / MISSING

For each Edge Case in PRD:
  Check if the UI handles it → PASS / MISSING

For each Business Rule in PRD:
  Check if the UI enforces it → PASS / MISSING
```

If any HIGH priority item is MISSING, implement it before reporting.

#### Step 9: Return Summary

```markdown
## Module Prototype Created

**Change**: {change-name}
**Platforms**: {Backoffice + App / Backoffice only / App only}

### Coverage
- **User Stories**: {X}/{Y} fully covered, {Z} partial
- **Edge Cases**: {X}/{Y} covered
- **Business Rules**: {X}/{Y} enforced
- **Overall Score**: {N}/10

### Files Created
- Types: {count} files
- Mocks: {count} files, {N} mock entities
- Hooks: {count} files, {N} queries, {M} mutations
- Components: {count} BO + {count} App
- Pages: {count}

### Known Gaps (if any)
| Gap | Reason | Priority |
|-----|--------|----------|

### How to Test
- BO: Navigate to /{route} or via sidebar
- App: Navigate to /{route} or via dashboard card
- Login: {credentials for local Supabase}

### Next Step
{/sdd-new {change-name} — to implement real backend}
{/module-prototype {change-name} — to improve gaps (EDIT mode)}
```

---

### Mode: EDIT

When prototype already exists and needs improvement.

#### Step 1: Retrieve Dependencies

Same as CREATE — get PRD and MDD from Engram.

#### Step 2: Audit Current Prototype

Read ALL existing prototype files. Run the same audit as CREATE Step 8:

```
For each User Story in PRD:
  Find implementing component(s)
  Check each AC → PASS / PARTIAL / MISSING

For each Edge Case → PASS / MISSING
For each Business Rule → PASS / MISSING
```

#### Step 3: Present Audit Report

Show the user:

```markdown
## Prototype Audit: {change-name}

### Score: {N}/10

### Gaps Found
| # | US/Edge Case/Rule | Status | What's Missing | Fix Effort |
|---|-------------------|--------|----------------|------------|
| 1 | US-005 Bulk reject | PARTIAL | No dialog for motivo | 20 min |
| 2 | US-019 Duplicates | MISSING | No IA scores in app | 30 min |

### What's Working Well
- {list of fully covered areas}
```

#### Step 4: Ask User

"Which gaps should I fix? All / Specific ones / Skip"

#### Step 5: Fix Approved Gaps

For each approved gap:
1. Read the specific component(s) that need changes
2. Implement the fix
3. Run TypeScript check
4. Commit with descriptive message

#### Step 6: Re-Audit and Report

After fixes, re-run the audit to confirm improvements:

```markdown
## Prototype Updated

**Before**: {X}/10
**After**: {Y}/10
**Gaps Fixed**: {count}
**Gaps Remaining**: {count} (with justification)
```

---

## Rules

- MUST read PRD AND MDD before generating — never generate from wireframes alone
- MUST generate types + mocks + hooks as shared foundation BEFORE UI components
- MUST NEVER create platform-specific types — one set of types for all platforms
- MUST verify every User Story AC is executable in the prototype before reporting "done"
- MUST implement Business Rules as UI validations (min chars, max items, required fields)
- MUST implement Edge Cases as UI states (empty state, error state, warning dialogs)
- MUST bypass ModuleGuard with TODO comment (feature flags don't exist for prototypes)
- MUST run TypeScript check and fix all errors before committing
- MUST add module to navigation (sidebar for BO, dashboard card for App)
- NEVER call real APIs — all data from mocks with React Query
- NEVER skip the audit step — it's what differentiates this skill from manual prototyping
- NEVER generate UI and types in parallel — types first, then UI
- Mutations should use setTimeout(500-1000ms) to simulate API latency
- Mock data should cover ALL filter combinations, ALL badge states, ALL edge cases
- For EDIT mode: read existing code before modifying — preserve what works, fix what's missing
