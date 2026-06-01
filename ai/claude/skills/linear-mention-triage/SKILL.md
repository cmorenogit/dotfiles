---
name: linear-mention-triage
description: >
  Triage César's pending Linear @mentions across his teams and draft in-lane replies, so he never scans Linear manually.
  Use when the user wants to check what mentions need his response, catch up on Linear, or follow up on pending comments.
  Triggers: "qué me menciona", "revisar mis menciones", "menciones pendientes", "triage Linear",
  "qué tengo pendiente en Linear", "ponerme al día con Linear", "/linear-mention-triage".
---

# Linear Mention Triage

Find César's **pending** Linear @mentions, classify each by whether it actually needs his
response, and draft confident **in-lane** replies — without him scanning Linear by hand.

Global skill: works from any session/cwd. Reads Linear + (on demand) code.
**NEVER posts to Linear** — drafts only; César posts.

## Identity & config (hardcoded)

- **User:** displayName `cmoreno`, id `6a1e659a-ca3d-417f-b460-b62307d9354d`, email `cmoreno@dcanje.com`.
- **Teams to scan:** Beat (`RYR`, id `ddeaea1c-b29b-45b4-82b2-6cd261c47aa5`), Platform (`PLA`), App Rewards (`APP`).
- **Watch targets (Phase 2, `--watch`):** Ignacio = id `1f03f08d-db10-4bf2-8999-499b7842f50c` (handle `@ignacio`). Otros: resolver con `list_users`/`get_user`.
- **Code access for verification (Pass 2):** R&R backend + backoffice = pm-agents `product_slug = "pulse"` (GitHub `ivaldovinos-app/apprecio-pulse`). The **R&R app/mobile frontend** = GitHub `ivaldovinos-app/ryr-39255`, which is **NOT** a pm-agents repo — reach it with the `gh` CLI (see Code access below). Bugs often span both (the app reads a field the backend sets), so you usually need both.
- **Digest output:** `~/Code/_vault/_work/apprecio/triage/linear/{YYYY-MM-DD}-{am|pm}.md` (`am` if local time < 13:00, else `pm`).
- **Output language:** Spanish (summaries + drafts). The skill's reasoning can be internal; what lands in the digest is Spanish.

At start, verify identity once: `get_user("me")` → confirm the id matches `6a1e659a-…`. If it differs, re-resolve before scanning.

## Tools (may be deferred — load first if needed)

- Identity: `get_user` (Linear native).
- Detection / read (Pass 1): prefer pm-agents `search_linear_issues` (lean candidate table — no descriptions) + `read_linear_issue` (one call = description + bounded comment thread via `comment_limit`). Linear native `list_issues` / `get_issue` / `list_comments` are the fallback and the way to honor the exact `--since` window (see Pass 1 §1).
- Code (Pass 2): pm-agents `grep_repo`, `read_repo_file`, `list_repo_files`, `list_product_repos`.

If these aren't directly callable, load their schemas via ToolSearch first:
`select:mcp__linear__get_user,mcp__linear__list_issues,mcp__linear__get_issue,mcp__linear__list_comments`,
`select:mcp__pm-agents-remote__search_linear_issues,mcp__pm-agents-remote__read_linear_issue`,
and `select:mcp__pm-agents-remote__grep_repo,mcp__pm-agents-remote__read_repo_file,mcp__pm-agents-remote__list_repo_files,mcp__pm-agents-remote__list_product_repos`.

### Code access (Pass 2) — THREE layers, in this order

1. **LOCAL clones (preferred — second opinion + cross-branch, READ-ONLY).** César keeps both R&R repos cloned under `~/Code/work/rr-project/`:
   - Frontend (`ivaldovinos-app/ryr-39255`): base clone `app-rr-cesar` (main); there may also be per-branch clones `app-rr-cesar.<feature>`.
   - Backend (`ivaldovinos-app/apprecio-pulse`): base clone `back-pulse-cesar` (main); same per-branch variants.
   - If a path differs, discover it: `find ~/Code/work/rr-project -maxdepth 2 -name .git`, then match origin with `git -C <dir> remote get-url origin`.
   - Use the **base** clone and read ANY branch WITHOUT checkout (full history, not shallow):
     - `git -C <base> fetch -q` (refreshes `origin/*`; does NOT touch the working tree)
     - `git -C <base> grep -n '<pattern>' <ref>` (ref = `origin/main` by default, or the PR's branch)
     - history / pickaxe: `git -C <base> log -S '<string>' -- <file>`, `git -C <base> log --oneline -- <file>`, `git -C <base> show <ref>:<file>`
   - **READ-ONLY, non-negotiable:** NEVER `checkout` / `pull` / `merge` / `reset` in his repos, and don't touch the `.<feature>` clones — the base clone + `git grep <ref>` already sees every branch.
2. **pm-agents `grep_repo`/`read_repo_file`** — works on its pre-configured repos: `app`, `backend`, `force-manager`, `pulse` (list with `list_product_repos`). Primary for `pulse`; also the **second opinion** to cross-check the local read — if they diverge, it's a different branch/state, so surface it. `ryr-39255` is NOT a pm-agents repo (admin-only `add_product_repo`; role `tl` is forbidden).
3. **`gh` CLI (fallback)** — only if no local clone exists. `gh repo clone <owner>/<repo> /tmp/<repo> -- --depth 50`, then `grep`/`sed` locally; history via `gh api "repos/<owner>/<repo>/commits?path=<file>"`. **NEVER conclude "I can't access the code."**

## Inputs

- `--since <Nd>` — lookback window (default `7d` → Linear `updatedAt="-P7D"`).
- `--teams <KEYS>` — comma list (default all 3: `RYR,PLA,APP`).
- `--verify <ISSUE-ID>` — run **Pass 2** (deep code verification) for one issue instead of the full triage.
- `--watch <person>` — run **Watch mode (Phase 2)**: surface OPTIONAL proactive opportunities on that person's mentions (default `ignacio`).

---

## Pass 1 — Triage (default invocation)

### 1. Detect pending mentions (scoped scan)

Linear has **no** "mentions-of-me" / inbox endpoint, so detection is a bounded scan:

1. For each team, enumerate candidates with pm-agents `search_linear_issues(team_key=<KEY>, limit=200)` — a **lean table** (identifier/title/state/priority/assignee/labels, NO descriptions), avoiding the ~70k-token blowup of `list_issues`. **Caveat:** `search_linear_issues` filters by state, **not** `updatedAt`, so it does NOT honor `--since <Nd>` on its own. To respect the window, keep one `list_issues(team, updatedAt="-P{N}D")` call parsed for **lean fields only** (id/identifier/title/updatedAt — never full descriptions) to get the in-window id set, or post-filter candidates by each one's `updatedAt`.
2. For each in-window issue, read it with `read_linear_issue(<IDENTIFIER>, comment_limit=<N>)` — one call returns description + a bounded comment thread (replaces `get_issue` + `list_comments`). Then detect the mention on the returned bodies, with **THREE patterns** (a mention can use any one):
   - **Description tag:** `<user id="6a1e659a-ca3d-417f-b460-b62307d9354d">` — match by **UUID** (the handle text is unreliable in descriptions).
   - **Comment @-mention:** `@cmoreno` in any comment body, **word-boundary** matched (so `@cmoreno2`/substrings don't false-match).
   - **Display-name in prose:** `@Cesar` / `Cesar` / `César` referenced in prose (description OR comments) WITHOUT the `@cmoreno` handle or UUID tag — match `C[eé]sar` word-boundary. This is a real recurring pattern the handle/UUID scan MISSES (e.g. "lo resolverá junto con Cesar", "@Nicole y @Cesar los apoyarán" — found invisible on RYR-87/RYR-88). **Dedupe** against the handle/UUID hits. These are usually prose name-drops → most land in `INFORMATIVO`, but they must be **seen**, not invisible.
3. **Pending filter:** a mention is *pending* if it appears AND there is **no** comment in that issue authored by `6a1e659a-…` (`author.id`) created **after** the mention. (Issue-level resolution for v1 — if César commented anywhere later in the issue, treat as handled.)
4. **Cost control & scaling:**
   - Prefer `search_linear_issues` (lean table) for enumeration; reserve `list_issues` only to resolve the `--since` window, and even then extract only lean fields (id, title, updatedAt, identifier) — its **full descriptions** blow the token budget (≈70k chars for ~50 issues). If a result is dumped to a file, parse that file for lean fields instead of reading it raw.
   - Bound `read_linear_issue` with `comment_limit`; only read in-window issues. **Never read code in Pass 1.** Summarize huge threads; don't load everything.
   - **Long threads silently truncate.** Threads with ~80+ comments / >90k chars (e.g. APP-17, APP-12) exceed `read_linear_issue`'s token limit and get cut — a mid-thread mention can be lost. For those: run the scan in a **sub-agent** and/or page comments (lowest `comment_limit` that still reaches the latest activity); don't trust a single truncated read.
   - For a busy team (many issues/window), run the comment-scan in a **sub-agent** that returns ONLY the pending matches (keeps the main context clean). **Then VERIFY the sub-agent's output** — re-pull each flagged issue's comments before reporting; sub-agents can produce false positives (one invented a pending mention this skill had to discard).

### 2. Classify each pending mention (lane gate)

Exactly one bucket:

- **REQUIERE RESPUESTA** — an @mention/CTA or question directed at César, **within his lane** (¿el dev cumplió lo necesario para avanzar a code review?).
- **NO ES TU LANE** — the ask is QA/merge approval (owner: **Ignacio**) or product scope / what's in-out (owner: **Nicole**). Name the owner; César does not answer.
- **INFORMATIVO / SIN ACCIÓN** — prose name-drop (not an `@`-tag), FYI, already resolved, or no open ask.

### 3. Draft replies (only for REQUIERE RESPUESTA)

For each, produce:
- **Resumen (plain):** 2-3 sentences a non-technical reader understands — what the problem is.
- **Borrador de respuesta:** confident, lean, in-lane, in Spanish (see Rules → Style). Tag any code claim `[inferido]` (not yet verified).
- **Por qué:** one line of reasoning.
- **Verificar:** which claims need Pass 2 (`--verify <ISSUE-ID>`) before posting.

### 4. Write the digest

Write to the digest path (am/pm by local time, one file per run — don't overwrite). Mark mentions that appeared in a prior digest and are still pending as **"viene de antes"**.

---

## Pass 2 — Verify (`--verify <ISSUE-ID>`)

Goal: confirm or correct each `[inferido]` claim against the REAL code, end-to-end.

**0. Analysis cache — recover before re-analyzing (don't re-trace from scratch).** Check `~/Code/_vault/_work/apprecio/triage/issues/<ISSUE-ID>.md`:
   - **No file** → full analysis (steps 1-7), then write the cache (step 8).
   - **File exists** → read it + `read_linear_issue(<ISSUE-ID>)`, then compare fingerprints:
     - Issue fingerprint (`last_comment_id` + `comments_count`) unchanged **AND** every `code_ref`'s `sha` unchanged → **return the cached analysis** ("sin cambios desde {last_analyzed}"). Don't re-trace.
     - **New comments** since `last_comment_id` → analyze ONLY the delta, using the cached diagnosis as context.
     - A new comment **contradicts** the cached diagnosis → re-analyze that part, flag the change.
     - A `code_ref`'s `sha` changed (`git -C <base> log -1 --format=%H <ref> -- <file>`) → re-verify ONLY those refs.
   - **The cache never overrides the code:** a hit returns the prior analysis only when BOTH fingerprints match; any mismatch → re-verify that part. The cache saves work, it never invents certainty.

1. `read_linear_issue(<ISSUE-ID>, comment_limit=<N>)` for full context — description + bounded comment thread in one call (native `get_issue` + `list_comments` is the fallback).
2. **Trace the LIVE path end-to-end — don't stop at one layer:** rendered component → hook/service → endpoint → backend handler → the exact field/computation. The bug usually lives where the contract diverges between two of these.
3. **Read the actual code (see Code access — THREE layers):** prefer the **local clones** in READ-ONLY mode — `back-pulse-cesar` (backend) and `app-rr-cesar` (app frontend) under `~/Code/work/rr-project/`; `git -C <base> grep -n '<pattern>' <ref>` reads any branch without checkout. Use **pm-agents** `grep_repo`/`read_repo_file` for `pulse` as primary AND as a **second-opinion cross-check** (**don't use `glob`** — search without it, read by path). `gh clone` is the fallback only when no local clone exists. NEVER mutate César's working tree (no `checkout`/`pull`).
4. **Anti-hallucination guards (hard-won — honor them):**
   - **Confirm the component is actually rendered** before reasoning about it — `grep` its usage. Dead/orphaned code (zero references) is a classic wrong turn.
   - **Follow the EXACT field the UI reads**, not a similarly-named one (e.g. UI reads `my_current`, not `current`).
   - **"Correct elsewhere" ≠ "correct in the consumed field"** — different surfaces hit different endpoints/fields.
   - **Ruling out one layer does NOT prove another.** Prove the failing line; don't infer it.
   - **Confirm the backend function/RPC is the LATEST definition** before trusting it — Postgres RPCs are `CREATE OR REPLACE`'d; a later migration can change behavior. Grep ALL definitions, read the newest.
   - **For a fix's COMPLETENESS, enumerate sibling paths.** If the fix touches a shared constraint/field (e.g. a CHECK allowlist), check ALL writers of that field, not just the reported one. (badge/ecard/challenge all write via the same grant path → a fix omitting one sibling is incomplete and re-leaves the same bug.)
5. **Fix-calibration gate (when the remedy touches a feature flag — hard-won from RYR-44).** A feature-flag bug has THREE mutually exclusive remedies; pick the right one PER flag, never a uniform "seed them all":
   | Flag state | How to confirm | Correct fix |
   |---|---|---|
   | Absent from `feature_flag_defaults` | `grep_repo(pulse, '<flag_key>')` finds the flag but no seed row | **SEED** `default_value=true` |
   | Already seeded `default=true` but off for one tenant | grep confirms the seed; symptom is tenant-scoped | It's an **OVERRIDE** in `tenant_feature_flags` (AND logic) — do NOT re-seed; check/clear the override |
   | **0 references in the backend** | `grep_repo(pulse, '<flag_key>')` = 0 matches | It was **never a backend flag** → cannot be seeded → fix is to **REMOVE the gate in the frontend** |
   - **Hard check before recommending "seed `<flag>`":** run `grep_repo(pulse, '<flag_key>')`. **0 matches → the seed recommendation is FORBIDDEN** (seeding a flag that doesn't exist in the backend sends Support chasing a ghost — the worst failure mode). Instead, **NAME the positive fix**: the gate lives only in the frontend, so the remedy is to REMOVE it there — grep the frontend repo (and its recent PRs) to point at the exact gate to delete. Don't settle for "check it at runtime".
6. Upgrade each claim to `[verificado: file:línea]` or correct it. **If you can't reach the code that decides it, say so and give the decisive runtime/DB check — do NOT publish a root cause you only inferred.**
7. Refine that one draft so it's safe to post (file:line accurate, no remaining `[inferido]`).
8. **Update the analysis cache.** Write/refresh `~/Code/_vault/_work/apprecio/triage/issues/<ISSUE-ID>.md` with the current fingerprints + diagnosis (format below), then commit it (the git history IS the "what we answered / what happened" trail). On a delta run, supersede only the parts whose fingerprint changed; don't discard the prior analysis.

### Analysis cache format

One file per issue at `~/Code/_vault/_work/apprecio/triage/issues/<ISSUE-ID>.md` (separate from the dated digests in `triage/linear/`). The fingerprints are how step 0 decides cache-hit vs re-analyze:

```markdown
---
issue: RYR-89
last_analyzed: 2026-05-30
issue_fingerprint: { last_comment_id: <id>, comments_count: 7 }   # changed → new comments to analyze
code_fingerprint:                                                 # changed sha → re-verify that ref
  - { ref: "apprecio-pulse@origin/main:supabase/functions/challenge-api/services/scorecard.service.ts", sha: "219c785" }
status: pendiente-bd        # | respondido | resuelto
verdict: "one-line root cause"
---
## Qué ocurre        (root cause + verified code_refs)
## Qué debe lograr    (fix + coverage)
## Qué se respondió   (what César posted + when — fill when known)
## Pendiente          (what still needs DB/runtime verification)
```

- **Code fingerprint** uses the local clone (Code access layer 1): `git -C <base> log -1 --format=%H <ref> -- <file>` is the **full 40-char sha** of the last commit touching that file on that ref (use `%H`, never the abbreviated `%h` — variable abbreviation length can cause false mismatches). Different sha → the verified line may have moved → re-verify before trusting the cached claim.
- **Pass 1 hook (future, not implemented):** the same fingerprint mechanism could let the triage scan skip unchanged issues; today Pass 1 still re-scans each run.

---

## Watch mode (Phase 2) — `--watch <person>`

Surface **OPTIONAL proactive opportunities**: open, technical asks directed at someone ELSE (default target: **Ignacio**, id `1f03f08d-db10-4bf2-8999-499b7842f50c`) where César's technical input would genuinely add value. This is OPT-IN and advisory — César decides whether to weigh in; the skill never auto-drafts an unsolicited barge-in or posts.

1. Resolve the watch target's id (Ignacio by default; `--watch <name>` → resolve via `list_users`/`get_user`).
2. Scan the teams (default RYR; honor `--teams`) for mentions of the target — `@ignacio` in comments + the target's UUID in descriptions — same scoped scan as Pass 1 (token-lean `list_issues`; sub-agent for the busy team + verify its output).
3. Keep ONLY items that pass ALL THREE gates:
   - **Open** — the technical ask/question is unresolved (no answer that closes it).
   - **Technical & in César's domain** — R&R code / architecture / technical-standard (his lane or adjacent), NOT pure process / QA / scheduling / product.
   - **César adds value** — he has real technical insight (a bug he traced, an architecture call, a path he knows). If unsure, **DROP it** — false positives here are pure noise.
4. For each survivor: plain summary + **why César could add value** + a SUGGESTED angle (NOT a finished draft) with `[inferido]` on any code claim. Mark each **OPCIONAL — vos decidís si intervenís**.
5. Output under a separate section **"Oportunidades proactivas (opcional)"** — NEVER mixed with "Requieren respuesta" (Phase 1). NEVER post.

**Bias:** prefer FEWER, higher-confidence opportunities. A noisy proactive list is worse than a short sharp one. Same verify-first gate applies before suggesting any code-specific angle.

---

## Rules (non-negotiable — these are the value of the skill)

**Lane.** César is the *technical-standard stopper*: he decides ONLY "¿el dev cumplió con todo lo necesario para avanzar a code review?". He does **not** approve QA or merges (→ **Ignacio**) and does **not** own product scope (→ **Nicole**). Drafts must never drift outside this. `NO ES TU LANE` items name the owner instead of drafting a reply.

**Intervention trigger.** Two distinct modes:
- **Default (Phase 1):** respond ONLY where there's an actual open ask directed at César (an `@`-mention/CTA, or a question he was tagged on). Being named in prose ("Ignacio lo resolverá junto con Cesar") is **not** an open ask → `INFORMATIVO`. Don't invent interventions.
- **`--watch` (Phase 2):** surface OPTIONAL proactive opportunities on someone ELSE's mentions (e.g. Ignacio), gated to open + technical + where-César-adds-value, always marked **OPCIONAL**. Even here: never auto-draft a barge-in, never post — only suggest an angle for César to decide.

**Style (drafts).** Confident and lean:
- No disclaimers, no role self-clarification ("aclaro mi lane…").
- No hedging ("el code review debería confirmar…").
- No spelling out assumed next steps ("el paso a QA queda en tu cancha").
- Lead with the verdict; then precise evidence. Answer what's asked, nothing more.

**Product alignment (Ignacio's lens).** Before finalizing any draft, consult `~/Code/_vault/_work/apprecio/_shared/ignacio-product-profile.md` and orient the draft toward what Ignacio (Jefe de Producto) prioritizes: lead with the business **outcome/metric** (not just the technical detail); make **QA state + next step + named owner** explicit; **root-cause, not patch**; **never propose removing a defense** (tenant predicate, RLS); prefer **centralizing cross-cutting concerns in the canonical RPC** over per-module patches; **`observe` before `enforce`** for rollouts. This is to **ALIGN** with his product lens — **NEVER to simulate him, speak for him, or attribute words to him.** **Format he expects:** open with the **outcome**; close with **status + next step + named owner** (+ date if relevant); when you're laying out **open decisions or scope options**, use his **ADLC decision table** (`#, Decisión, Opciones, Recomendación, Status`) instead of prose. Keep it confident and lean — use the table ONLY for decisions-to-make, not for every reply.

**Rigor (anti-hallucination).** Never assert a code fact from comments alone — tag `[inferido]` until confirmed `[verificado: file:línea]`. Never assert a **root cause** until the live path is traced end-to-end (the component is actually mounted, the exact consumed field, its endpoint, its backend computation/RPC — confirmed the latest definition). Ruling out one layer ≠ proving another. **A confident-but-wrong verdict is worse than "not 100% yet — here's the decisive check."** A draft with `[inferido]` code claims must not be posted as-is. **Never propose a fix without calibrating it per affected entity:** for feature flags, run the Fix-calibration gate (Pass 2 §5) — seed / tenant-override / remove-frontend-gate are mutually exclusive, and `grep_repo(pulse, '<flag>')` = 0 forbids any seed recommendation.

**Publishing gate (two states only).** Never hand over a publish-ready draft until it's verified end-to-end. Only two states exist: **"100% verificado — acá está el draft"** OR **"todavía no — esto es lo que falta verificar."** Never a confident draft in between. **The verification gate is the skill's, not the user's — they should never have to ask "¿verificaste?".**

---

## Digest format

```markdown
# Triage Linear — {YYYY-MM-DD} ({AM|PM})
_teams: RYR,PLA,APP · ventana {N}d · {X} issues escaneados · {Y} menciones pendientes_

## Requieren respuesta ({K})

### {ISSUE-ID} — {título corto}
- **Quién / cuándo:** {autor} · {top-level | reply} · {fecha}{ · viene de antes}
- **Problema:** {resumen plain, 2-3 frases}
- **En tu lane:** Sí — {por qué}
- **Borrador:**
  > {respuesta confiada, lean, en español}
- **Por qué:** {razón en 1 línea}
- **Verificar:** {claims [inferido]} → `/linear-mention-triage --verify {ISSUE-ID}`

## No es tu lane ({J})
- **{ISSUE-ID}** — {qué piden} → owner: **{Ignacio | Nicole}**

## Informativo / sin acción ({M})
- **{ISSUE-ID}** — {por qué no requiere acción}
```

---

## Notes / gotchas

- **Mention encoding differs (THREE patterns):** comment bodies use plain `@cmoreno` (word-boundary); descriptions use `<user id="UUID">` (match the UUID); and **prose can name `Cesar`/`César` by display-name with no handle/tag** — scan `C[eé]sar` too (dedupe vs the handle/UUID hits), or those mentions stay invisible (real gap found on RYR-87/RYR-88).
- **`list_issues` returns full descriptions** → can exceed the token limit (~70k for 50 issues). Parse for lean fields only; if dumped to a file, slice/grep the file.
- **Pass 1 cost:** prefer pm-agents `search_linear_issues` (lean table) for enumeration and `read_linear_issue(comment_limit=N)` for per-issue context — reserve `list_issues` only to resolve the `--since` window. `search_linear_issues` filters by state, not `updatedAt`, so it doesn't honor `--since` on its own.
- **Fix-calibration gate (feature flags):** never recommend "seed a flag" without `grep_repo(pulse, '<flag>')` first — 0 matches means it's not a backend flag and the fix is to remove the frontend gate, not seed. Seed / tenant-override / remove-gate are mutually exclusive (Pass 2 §5).
- **`grep_repo` `glob` is unreliable** — search without it, then read by path.
- **Code beyond pm-agents' 4 repos** (esp. the R&R app `ivaldovinos-app/ryr-39255`) → prefer the LOCAL clones under `~/Code/work/rr-project/` (`app-rr-cesar` front, `back-pulse-cesar` back) in READ-ONLY mode (`git grep <ref>` reads any branch without checkout); `gh` CLI is the fallback. Don't say "inaccessible". Registering `ryr-39255` in pm-agents via `add_product_repo` is admin-only (role `tl` is forbidden).
- **Local clones are READ-ONLY for the skill:** `fetch` / `git grep <ref>` / `log` / `show` only — NEVER `checkout` / `pull` / `merge` / `reset` (don't disturb César's working tree or in-progress branches). Use the base clone + `git grep <ref>` to see any branch; leave the `.<feature>` clones untouched.
- **Dead-code trap:** before basing an analysis on a component, confirm it's actually imported/rendered (`grep` its usage).
- **Large threads** (e.g. governance comments) can blow the token budget — bound `list_comments`, summarize, never load full code in Pass 1; consider a sub-agent + verify its output.
- **Storage is vault-only.** Do **not** write to engram from this skill. The per-issue **analysis cache** (`triage/issues/<ISSUE-ID>.md`) is vault-only too — chosen over engram because recovery is by exact key (the ISSUE-ID) + fingerprint diff, not semantic search, and it must work in headless/cron runs where the engram MCP may be absent.
- **Never post to Linear.** The skill drafts; César reviews and posts.
