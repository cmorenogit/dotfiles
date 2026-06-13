---
name: pr-review-ccc
description: Cross-cutting concerns review for a PR. Auto-detects affected modules, checks auth, tenant isolation, feature flags, CORS, API architecture, tridimensional model, validation, error handling, i18n with evidence-based guardrails.
---

# Cross-Cutting Concerns Review

**Usage:** `/pr-review-ccc {prNumber}` or `/pr-review-ccc {prNumber} --repo owner/repo`

## Step 1: Gather PR Context

1a. Parse PR number. **Resolve `{repo}`** in this order: (1) `--repo owner/repo` if passed; (2) auto-detect via `gh repo view --json nameWithOwner -q .nameWithOwner` from cwd; (3) if both fail, ask the user and stop.

1b. Get PR info:
```bash
gh pr view {prNumber} -R {repo} --json title,body,changedFiles,headRefOid --jq '{title,body: .body[0:500],changedFiles,head: .headRefOid}'
```

1c. Get the diff:
```bash
gh pr diff {prNumber} -R {repo} > /tmp/pr{prNumber}.diff
```

If diff fails (>20K lines), fetch files by priority order:
1. `supabase/migrations/*` (schema changes first)
2. `supabase/functions/*/routes/*`, `*/services/*` (business logic)
3. `supabase/functions/_shared/*` (shared modules)
4. `src/modules/*`, `src/hooks/*` (frontend pages/hooks)
5. `src/locales/*` (locale files — last priority)

Use `gh api repos/{repo}/contents/{path}?ref={headSha}` to fetch individual files.

## Step 2: Auto-Detect Affected Modules

From the changed files, identify:

- **Edge functions:** Files under `supabase/functions/*/` — extract function names (e.g., `supabase/functions/challenge-api/routes/index.ts` → `challenge-api`).
- **Shared modules:** Files under `supabase/functions/_shared/` — trace which edge functions import them:
  ```bash
  # For each changed _shared module, find importers
  gh api repos/{repo}/contents/supabase/functions?ref={headSha} --jq '.[].name'
  # Then check each function's files for imports of the changed module
  ```
- **Migrations:** Files under `supabase/migrations/` — extract table/function/policy names from the SQL.
- **Frontend modules:** Files under `src/modules/*/`, `src/components/*/`, `src/hooks/*` — extract module names.
- **Locale files:** Files under `src/locales/{en,es,fr,pt}/*` — flag for i18n parity check.

Build a deduplicated list of affected modules and report: `"Modules affected: {list}"`

## Step 3: Launch 3 Agents in Parallel

**Agent 1 — Security + Auth + RLS + Tenant + Cron + Notifications + Shared reuse:**
- Scope: Backend files only (edge functions, migrations, _shared)
- Checklist sections: AUTH, TENANT, FLAGS, CORS, ERRORS, CONCURRENCY, **CRON**, **NOTIFICATIONS**, **SHARED_REUSE** (incluye RATE_LIMIT)
- Give the agent the FULL text of those checklist sections below

**Agent 2 — API Architecture + Points Model + Locks + Validation:**
- Scope: Backend files only (edge functions, migrations, _shared)
- Checklist sections: ARCH, POINTS, **LOCKS**, VALID
- Give the agent the FULL text of those checklist sections below
- This agent is separate because the tridimensional points model + locks are complex and need focused attention

**Agent 3 — Frontend + i18n + Accessibility + Types:**
- Scope: Frontend files + locale files
- Checklist sections: I18N, A11Y, TYPES, ERRORS_FE, VALID_FE
- Give the agent the FULL text of those checklist sections below

Each agent receives the list of affected modules from Step 2 so it knows what to focus on.

## Hard Guardrails (give these to ALL agents)

- **Evidence-first rule:** Never claim "X is missing" without searching for it first. Include the search query and result summary.
  - Before flagging "no Zod validation" → search the file for `z.object`, `z.string`, `.parse(`, `.safeParse(`.
  - Before flagging "no RLS" → search migrations for `ENABLE ROW LEVEL SECURITY` on the table.
  - Before flagging "no auth middleware" → search for `app.use('*', authMiddleware)` or `c.get('auth')`.
- **Multi-migration awareness:** When reviewing SQL migrations, check ALL migrations in the PR chronologically. A later migration may add the RLS/index/constraint that an earlier one omits. Do NOT flag an issue that's resolved by a subsequent migration.
- **Shared module impact:** When flagging an issue in a `_shared/` module, identify which edge functions import it (impact radius). Report: `"Affects: {api-1}, {api-2}, ..."`
- **Test file exclusion:** Do NOT flag test files for production-level concerns unless there's a security leak in test data (hardcoded real API keys, real customer data, production URLs).
- **Only flag with DIRECT EVIDENCE in the code.** Do not speculate about what might be missing elsewhere.

---

## Backend Checklist

### AUTH — Auth and guards
- No unprotected admin/manager paths.
- All routes use `authMiddleware`, `requireRole`, or equivalent.
- User identity comes from JWT/auth context, NEVER from request body `user_id`.
- Manager scope validated via `is_org_manager` RPC or `departments.manager_id` / `teams.manager_id`, NOT from `profiles.department_id` + `user_roles.role`.

### TENANT — Tenant isolation and RLS
- No cross-tenant data exposure.
- All queries using `adminClient` (service role) MUST include `.eq('tenant_id', tenantId)`.
- Views accessed via `adminClient` should have `security_invoker = true` or explicit tenant filter.
- Triggers and functions that modify data across tables must resolve and scope by `tenant_id`.
- **RLS policies MUST filter by `tenant_id`**, not just `user_id`. A policy with only `user_id = auth.uid()` allows cross-tenant access for multi-tenant users. Correct pattern: `AND tenant_id IN (SELECT tenant_id FROM user_roles WHERE user_id = auth.uid())` or equivalent tenant membership check.
- **Realtime subscriptions** on multi-tenant tables must include `tenant_id` in the channel filter, not just `user_id`.

### FLAGS — Feature flags
- Gated features use the `feature-flag-middleware.ts` Hono middleware or `is_feature_enabled` RPC.
- Pattern is **fail-closed**: if flag doesn't exist → feature disabled.
- New modules MUST have a corresponding flag in `feature_flag_defaults`.
- Backend and frontend must BOTH check the flag (not just one side).
- **Sub-flag → master flag coherence:** if a sub-flag is checked (e.g., `ecards_moderation_enabled`), the master flag (`ecards_grupales_enabled`) MUST also be checked in the same gate. Sub-flag without master = MUST FIX.
- **Migration in same PR:** if the PR introduces a new flag key in code (middleware call or `is_feature_enabled(_, 'new_key')`), the migration that inserts the default row into `feature_flag_defaults` MUST be in the SAME PR. A flag without default row resolves to NULL → `is_feature_enabled` returns false → feature dead on arrival in production. MUST FIX.
- **Kill-switch convention:** kill-switches (flags that disable an entire module — e.g., `ai_reports_kill_switch`, `recognition_kill_switch`) are default-ON, tenant-scoped, and checked at the top of the route handler before any logic runs. If a PR adds a module with operational risk (external API, expensive query, novel feature) without a kill-switch, flag as SHOULD FIX.

### CORS — CORS handling
- Hono apps: use `createCorsMiddleware()` from `_shared/cors.ts`.
- Legacy functions: use `getCorsHeaders(req)` + `handlePreflight` from `_shared/cors.ts`.
- MUST reject requests when origin is not allowed (not just omit headers).
- No hardcoded `Access-Control-*` headers outside of `_shared/cors.ts`.
- Check ALL edge functions in the PR, including legacy ones (check-streaks, webhooks).

### ARCH — API architecture (Edge Functions)
- Consolidated APIs: Hono router with `routes/`, `services/`, `utils/`.
- Auth: `authMiddleware` and `requireRole` from `utils/auth.ts`.
- Responses: `jsonSuccess` / `handleError` from `utils/response.ts`.
- Errors: `AppError` and `ErrorCodes` from `utils/errors.ts`.
- External calls: `fetchWithResilience` from `_shared/integration-utils.ts` with `correlationId`.
- `config.toml` updated for new functions (`verify_jwt` as appropriate).
- Same `@supabase/supabase-js` version across functions and `_shared/` (no drift).

### POINTS — Tridimensional model (XP, Economic, Recognition)
This is critical. The system has 3 point types with specific grant patterns:

**XP grants:**
- Module-specific RPCs: `grant_training_xp`, `grant_challenge_xp`, `grant_survey_xp`, etc.
- Generic `grant_xp` only for legacy/simple cases.
- Each RPC handles idempotency, milestone proportional calculation, and candado validation internally.

**Economic grants:**
- Module-specific RPCs: `grant_training_economic`, `grant_economic`.
- MUST call `validate_point_grant(module, 'economic', amount, tenant_id)` before granting.
- Uses `_shared/economic-grant-utils.ts` for `SOURCE_TYPE_TO_MODULE` mapping.

**Recognition grants:**
- **ALWAYS** via `grantRecognitionInternal()` from `_shared/recognition-service.ts`.
- NEVER via direct RPC or DB insert.
- Requires: `giverId`, `receiverIds`, `pointsPerReceiver`, `tenantId`, `sourceType`, `idempotencyKey`, `authToken`.
- Valid `sourceType` values: `'award' | 'occasion' | 'automatic_event' | 'mission' | 'ai_assistant' | 'recognition_type' | 'spot_reward' | 'challenge'`.
- Uses `fetchWithResilience` internally to call `recognition-grant` edge function.

**What to check:**
- Is the correct RPC/service used for each point type? (not `grant_xp` for recognition)
- Is `validate_point_grant` called before economic/recognition grants?
- Are `source_type` values in the allowed whitelist?
- Is the parameter naming correct? (`_source_name` for `grant_xp`, `p_source_name` for `grant_economic`, `message` for `grantRecognitionInternal`)
- Is idempotency handled? (key format, collision risk)
- Budget/scope validation for recognition? (recognition uses budget scopes: company/department/team/manager/user)

Note: `module_point_locks` checks moved to the LOCKS section.

### VALID — Validation
- All new endpoints have Zod schema validation.
- UUID parameters validated before DB queries.
- Schemas use `.strip()` not `.passthrough()` (prevent field injection on DB inserts).
- Search/filter inputs sanitized before PostgREST interpolation.

### ERRORS — Error handling
- No secrets in error responses (env var names, DB table names, constraint details, stack traces).
- Use `safeErrorResponse` or `AppError` for client responses.
- Raw `error.message` from Supabase/DB NEVER forwarded to client.
- Log full error details server-side with `console.error`.

### CONCURRENCY — Race conditions y atomicidad
- Read-then-write counters sin proteccion atomica (rate limits, awarded_count, budget). Ver LOCKS para los mecanismos validos.
- Multi-step writes (2+ INSERT/UPDATE) sin transaccion (BEGIN/COMMIT, RPC, `.rpc('*_atomic*')`).
- Self-referential logic: approver_id = requester_id, giver_id = receiver_id sin allowance explicito.
- Operaciones no-idempotentes sin idempotency keys o ON CONFLICT.

Note: candados (advisory, point, giver) tienen seccion propia (LOCKS).

### CRON — pg_cron jobs y paridad prod ↔ preview

Toda migracion con `cron.schedule(...)` debe cumplir el formato canonico de `docs/cron-canonical-format.md` (PR #355). El parser `scripts/extract-cron-manifest.ts` bloquea drift en CI; detectarlo en CCC da feedback temprano antes de que el parser rechace el PR.

**Reglas obligatorias (MUST FIX si falla cualquiera):**

- **Jobname:** kebab-case `[a-z0-9-]{1,63}`, unico en el repo. Grep otras migraciones por colision.
- **Schedule:** cron 5-field POSIX (UTC implicito).
- **URL canonica:** literalmente `current_setting('app.settings.supabase_url', true) || '/functions/v1/<edge-function-name>'`. Prohibido: URL hardcoded (`https://*.supabase.co`), `app.supabase_url` sin namespace `settings`, `format()`, variables locales, fallback hardcoded.
- **Headers:** `jsonb_build_object(...)` con `Content-Type` + uno o mas de los 3 auth headers canonicos:
  - `'x-supabase-cron', 'true'` (valor literal exacto)
  - `'x-cron-secret', current_setting('app.settings.cron_secret', true)`
  - `'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)`
  El VALOR del header de auth se valida (no solo la clave). Hardcodear secretos (`'Bearer eyJ...'`, `'literal-secret'`) = CRITICAL (token expuesto en repo publico).
- **Settings canonicos:** los 3 namespaced bajo `app.settings.*` (`supabase_url`, `cron_secret`, `service_role_key`). Variantes sin namespace (`app.supabase_url`, `app.service_role_key`) = MUST FIX (Supabase managed no setea esos automaticamente; quedan NULL en prod).
- **Dollar-quoting:** solo `$$ ... $$`. Tagged dollar quotes (`$tag$ ... $tag$`) no se soportan por el parser.
- **Body:** `jsonb_build_object(...)` o JSON literal `'...'::jsonb`. Determinístico (sin `now()` salvo como timestamp tag).
- **Direct-SQL jobs:** body = un solo `SELECT <schema>.<fn_name>(<literal_args>)`. Schema explicito (`public.`, no implicit search_path). Args literales.
- **Direct-SQL + paridad preview:** si el PR agrega un cron `direct-sql` nuevo, DEBE actualizar `supabase/functions/cron-direct/index.ts` (`ALLOWED_ACTIONS` map) y agregar test en `cron-direct/__tests__/unit/handler.test.ts`. Sin esto el cron funciona en prod (pg_cron + pg_net nativos) pero rompe silenciosamente en preview Cloud Scheduler. MUST FIX.
- **Receptor HTTP:** la edge function destino DEBE validar `x-supabase-cron === 'true'` (o `x-cron-secret` timing-safe). Grep su `index.ts` o `routes/*.ts` por la validacion; si no existe = MUST FIX (endpoint cron sin auth).
- **Unschedule pattern:** si la migracion reemplaza un cron existente, usar `DO $$ BEGIN PERFORM cron.unschedule('name'); EXCEPTION WHEN OTHERS THEN NULL; END $$;` antes del nuevo `cron.schedule` (idempotente).

**Anti-FP:**
- `cron.unschedule` puro (sin reschedule) = aceptable.
- `cron.alter_job` cambiando solo schedule (sin tocar URL/headers/body) = aceptable.

### LOCKS — Candados de concurrencia y atomicidad

Consolida los 3 tipos de candado del repo. Cualquier mutacion compartida (counter, balance, otorgamiento) sin uno de estos mecanismos = MUST FIX.

**Mecanismos validos:**

- **Advisory locks** (`pg_advisory_xact_lock(key)`): para coordinacion ad-hoc entre transacciones concurrentes sobre una misma entidad. Key debe ser determinística (hash estable del recurso, no `random()`).
- **`SELECT ... FOR UPDATE`:** para read-then-write sobre filas especificas dentro de una transaccion.
- **`module_point_locks`** (tabla): candado del modelo tridimensional para evitar doble otorgamiento por modulo/source. Usado por los RPCs `grant_*_xp`, `grant_*_economic`, `grantRecognitionInternal`. NO acceder directo desde edge function — el RPC ya lo maneja.
- **Giver locks** (introducido en PR #156, spot-rewards): tabla/RPC dedicado para limitar cuanto puede emitir un giver dentro de una ventana. Patron canonico: RPC `spot_reward_create_atomic` que combina giver-lock + idempotency key + insert en una sola transaccion. Cualquier nuevo "lock por actor" (giver, requester, approver) debe seguir este patron, NO un read-then-write desde la edge function.

**Reglas:**

- **Read-then-write sobre counter** (rate limit, awarded_count, budget, wallet balance) sin uno de los mecanismos anteriores = MUST FIX. La proteccion DEBE estar dentro de un RPC atomico, no en el codigo de la edge function (edge function corre fuera de la transaccion DB).
- **Naming convention:** RPCs que combinan lock + mutacion = sufijo `_atomic` (`spot_reward_create_atomic`, `grant_xp_atomic`). Tablas de lock = sufijo `_locks` (`module_point_locks`, `giver_locks`). Si una RPC mutante no sigue la convencion, SHOULD FIX.
- **Lock + idempotency combinados:** si la operacion es no-idempotente Y tiene riesgo de race, ambos checks DEBEN ir en la misma RPC atomica. Separarlos (lock en una RPC, idempotency check en otra, INSERT en una tercera) abre ventana de race. MUST FIX.
- **Gap a flaggear:** el repo no tiene `_shared/lock-utils.ts`. Si el PR introduce un nuevo tipo de lock y la implementacion vive solo en una RPC SQL, sugerir como CONSIDER agregar helper TS que documente las RPCs `*_atomic*` disponibles.

### NOTIFICATIONS — Sistema de notificaciones

Hay un sistema canonico unico en `_shared/notification-service.ts` con la entrada `emitNotificationEvent()`. Cualquier emision de notificacion fuera de ese canal genera estado divergente.

**Reglas:**

- **Entrada canonica:** toda emision de notificacion DEBE pasar por `emitNotificationEvent()` de `_shared/notification-service.ts`. La funcion encadena: feature-flag check (`notifications_enabled` per tenant) → preference check (`check_notification_preference` RPC) → insert + dispatch.
- **Prohibido INSERT/UPDATE directo** a `in_app_notifications` ni a `notification_delivery_log` desde edge functions que no sean `notification-api`, `notification-purge`, `notification-retry`, o el propio `_shared/notification-service.ts`. MUST FIX.
- **Tabla canonica:** existe ambivalencia entre `notifications` (vieja) e `in_app_notifications` (introducida por PR #156). Si el PR introduce una tercera tabla con semantica de notificacion (`*_notifications`, `*_messages`), MUST FIX — exigir unificacion con la tabla canonica.
- **Email channels** (`notification-email-click`, `notification-email-digest`) son SINKS del sistema, NO entradas alternativas. Una edge function que necesita "enviar email" debe llamar `emitNotificationEvent` con `channel: 'email'`, no llamar al email function por HTTP.
- **Acoplamiento cruzado:** si una edge function NO-`notification-*` importa de `notification-api/services/*.ts` (e.g., `NotificationTracker`), flaggear como SHOULD FIX — el shared deberia abstraerlo. Excepcion: `_shared/notification-service.ts` puede importar de `notification-api/` mientras viva ese acoplamiento legacy (a refactorizar).

**Anti-FP:**
- Queries de LECTURA sobre `in_app_notifications` (SELECT para mostrar la lista al usuario) son aceptables — la regla aplica solo a mutaciones.
- Edge functions `notification-purge` / `notification-retry` operando directo sobre la tabla son aceptables — su unico proposito ES mantener esa tabla.

### SHARED_REUSE — Reuso de modulos shared

`_shared/` existe para evitar reimplementaciones divergentes. Cuando un PR reimplementa funcionalidad que ya vive en `_shared/`, el riesgo no es estilistico sino operacional: el patron canonico tiene tests, observabilidad y precision conocidas; la reimplementacion no.

**Modulos canonicos y su responsabilidad:**

| Modulo `_shared/` | Responsabilidad | Senal de evasion |
|---|---|---|
| `cors.ts` | `createCorsMiddleware`, `getCorsHeaders`, `handlePreflight` | hardcoded `'Access-Control-Allow-Origin'` en headers de respuesta |
| `observability-middleware.ts` | trace_id, correlation_id, latency log estructurado | edge function nueva sin `app.use('*', observabilityMiddleware)` y con `console.log` ad-hoc |
| `storage-adapter/` | upload/download/remove via abstraccion (preview vs prod paths) | `admin.storage.from(...).{remove,upload}` directo |
| `rate-limit.ts` | `enforceRecoveryRateLimit` y patron RPC fail-closed | nueva clase/funcion de rate-limit con interfaz distinta |
| `notification-service.ts` | `emitNotificationEvent` (ver seccion NOTIFICATIONS) | INSERT directo a `in_app_notifications` |
| `integration-utils.ts` | `fetchWithResilience` (retries + correlationId) | `fetch()` directo a integraciones externas (DDM, gestion-puntos, apprecio-identity) |
| `auth-utils.ts` | parsing JWT, derivacion de `auth` context | parseo manual de JWT con `jose` o split del bearer string |
| `recognition-service.ts` | `grantRecognitionInternal` (ver seccion POINTS) | INSERT directo a `recognition_transactions` |
| `org-manager.ts` (gap) | wrapper de `is_org_manager` RPC | inline `rpc('is_org_manager', ...)` repetido N veces |

**Reglas:**

- **Evasion = MUST FIX por defecto.** El PR debe justificar explicitamente por que el `_shared/` existente no aplica (e.g., contrato distinto, performance, semantica). La justificacion debe estar en el body del PR o en un comment inline en el codigo nuevo.
- **Si el patron shared NO existe** (gap real, como `_shared/cron-auth.ts` o `_shared/lock-utils.ts`), la regla cambia: en lugar de exigir reuso, exigir que el PR cree el shared y lo use desde el dia 1 — o crear ticket de followup con owner asignado.
- **Cross-PR coupling:** una edge function NO-`_shared` importando de OTRA edge function (e.g., `notification-api/services/notification-tracker.ts` importada desde `_shared/notification-service.ts` o desde otra api) = SHOULD FIX. Refactorizar al shared o duplicar locally.

#### RATE_LIMIT — sub-seccion

Caso especial de SHARED_REUSE por la fragmentacion actual (3 implementaciones incompatibles en main: `_shared/rate-limit.ts`, `api-surveys/helpers/rate-limiter.ts`, `recognition-api/routes/rate-limits.ts`).

- Cualquier rate-limiter nuevo DEBE extender `_shared/rate-limit.ts` o documentar excepcion explicita en el PR body.
- No crear modulo rate-limiter ad-hoc dentro de una edge function. Si la semantica requiere algo distinto (e.g., per-giver lock como spot-rewards), encajar como nueva exportacion del shared, no como modulo paralelo.
- Si el rate-limit requiere atomicidad (no doble-deduccion bajo carga), ver LOCKS — la implementacion debe ser RPC `*_atomic*`.

---

## Frontend Checklist

### I18N — Internationalization
- All new user-facing strings use `t()` from `useTranslation`.
- Keys exist in ALL locale files (en, es, fr, pt) — check key parity.
- `defaultValue` fallbacks should be in English (not Spanish).
- `date-fns` locale should be dynamic (`getDateLocale(i18n.language)`), not hardcoded `{ locale: es }`.
- Backend `source_name` and `message` fields that reach the user should be i18n-friendly (no hardcoded Spanish like `'Mision: ${name}'`).
- Check `docs/TODO_TRAININGS_I18N.md` for known i18n gaps — flag if the PR makes them worse.

### CMD_PALETTE — Command Palette catalog sync

El Command Palette (`src/components/command-palette/catalog.ts`) es la fuente de verdad navegacional del producto. PR #359 establecio la regla cross-cutting: cada PR que toca rutas, tabs deep-linkables, modales URL-disparables, kill-switches o feature flags de navegacion DEBE actualizar el catalog en el MISMO PR. No existe ticket separado de "Update Command Palette".

**Estructura del catalog:**
- `pageCatalog: CommandItem[]` — top-level pages + deep-link tabs
- `actionCatalog: CommandItem[]` — actions + modal-actions
- `CommandItem.requiresFlag?: KnownFeatureFlag` — gate de visibilidad por flag
- `KnownFeatureFlag` (union type) — flags conocidos al catalog; entry con flag fuera del union = TS error en compile time
- `useDeepActionFlagMap` (`CommandPalette.tsx`) — resuelve `KnownFeatureFlag` → boolean en runtime
- `useCommandPaletteAccess` — gate global: `isAdmin && command_palette_enabled`
- i18n: `src/locales/{en,es,fr,pt}/command-palette.json` — paridad de keys obligatoria

**Triggers (si CUALQUIERA aplica, exigir update al catalog en el MISMO PR):**

- PR agrega `<Route path="/X">` en `src/App.tsx` (o router equivalente) → exigir entry en `pageCatalog` con `category: 'page_top_level'`, label en los 4 locales
- PR agrega `useSearchParams` para `?tab=X` en una pagina (deep-link tab) → exigir entry con `category: 'tab_deep_link'`, URL incluye `?tab=...`
- PR agrega `useEffect` lector de `searchParams.get('action')` que abre modal → exigir entry en `actionCatalog` con `category: 'modal_action'`
- PR renombra o borra una ruta presente en el catalog → exigir update/borrado del entry (grep `catalog.ts` por la URL vieja)
- PR introduce un nuevo `useFeatureFlag('X', tenantId)` que gate una seccion navegable → las entries afectadas DEBEN tener `requiresFlag: 'X'`, `'X'` DEBE estar en `KnownFeatureFlag` union, y `useDeepActionFlagMap` DEBE resolverlo
- PR introduce un kill-switch (default-ON) para un modulo navegable → mismas 3 condiciones de arriba (entry con `requiresFlag`, union actualizado, flagMap resuelto)
- PR modifica `KnownFeatureFlag` union (agrega/quita flag) → audit de `useDeepActionFlagMap` (sync con union) + entries con `requiresFlag` huerfano

**Reglas obligatorias (MUST FIX si falla):**

- **Ruta sin entry:** ruta nueva admin-accesible ausente del `pageCatalog` → MUST FIX (feature shipping invisible al usuario)
- **Entry → 404:** entry con `url` que no resuelve a ruta valida en `App.tsx` (ruta renombrada/borrada sin update del catalog) → MUST FIX
- **Flag gate ausente:** seccion con `useFeatureFlag('X')` que gate render Y entry sin `requiresFlag: 'X'` → MUST FIX (entry zombie cuando flag OFF)
- **Flag fuera del union:** entry con `requiresFlag: 'X'` donde `'X'` no esta en `KnownFeatureFlag` union → MUST FIX (TS error en cliente; el CCC lo flagea con remediation hint)
- **Falta i18n:** entry con `labelKey: 'pages.X'` que no existe en uno o mas de los 4 locales `command-palette.json` → MUST FIX (key literal renderizada en produccion)
- **Kill-switch no respetado:** PR agrega kill-switch para un modulo navegable pero las entries del modulo no agregan `requiresFlag` del kill-switch → MUST FIX (modulo apagado pero descubrible via palette)

**Anti-FP (NO flaggear):**
- Rutas privadas no-admin (`/auth/login`, `/onboarding/...`) — el catalog es admin-only por `useCommandPaletteAccess`
- Rutas de detalle dinamicas (`/usuarios/:id`, `/reconocimientos/:id`) — el palette indexa entry points, no instancias
- PRs que solo renombran archivos sin cambiar URLs publicas
- PRs que solo cambian markup interno de una pagina existente (sin agregar tab/modal nuevo)

### A11Y — Accessibility
- Interactive elements (buttons, switches, tooltips) have `aria-label` or visible label.
- Tooltip triggers are keyboard-focusable (`tabIndex={0}` or wrapped in `<button>`).
- Form inputs have associated labels.
- `disabled` state set during mutations to prevent double-submit.

### TYPES — Type safety
- No `as any` casts hiding real type gaps.
- API response types defined (not `Record<string, unknown>` everywhere).
- Missing interface fields added instead of casting.

### ERRORS_FE — Frontend error handling
- Catch blocks show user-facing feedback (toast, error state), not just `console.error`.
- API errors preserve error codes from backend (not just `throw new Error(message)`).

### VALID_FE — Frontend validation
- Form validation present for new/modified forms.
- API responses validated or at least null-checked before rendering.

---

## Step 4: Cross-Section Validation

After collecting findings from all 3 agents, check for coherence across sections:

1. **Auth-RLS coherence:** If a new route is added without `authMiddleware`, check whether there's a corresponding RLS policy in the migrations that would protect the data anyway.

2. **Feature flag coherence:** If a new feature module is added, verify BOTH backend flag check (`is_feature_enabled` / middleware) AND frontend flag check exist. If Agent 1 found a backend flag and Agent 3 didn't find a frontend flag (or vice versa), flag it.

3. **Points model coherence:** If a point grant is added in one module, verify idempotency key format doesn't collide with other modules' keys. Check `SOURCE_TYPE_TO_MODULE` mapping is updated if new source type.

4. **i18n parity:** If Agent 3 found locale file changes, verify all 4 locales (en/es/fr/pt) have the same keys added.

5. **Schema-API coherence:** If Agent 2 found a new Zod schema, verify the corresponding route actually calls `.parse()` or `.safeParse()` on it.

6. **Cron HTTP target coherence:** For every `cron.schedule` with `type: http` in the PR migrations, verify the target edge function (a) exists in this PR or in `origin/main`, AND (b) validates `x-supabase-cron` o `x-cron-secret` en su `index.ts` o `routes/*.ts`. Missing either = MUST FIX.

7. **Cron direct-sql preview parity:** For every `cron.schedule` with `type: direct-sql` in the PR migrations, verify `supabase/functions/cron-direct/index.ts` is modified in the same PR with the action added to `ALLOWED_ACTIONS`. If not = MUST FIX (cron works in prod but breaks in preview).

8. **Feature flag default registration:** If the PR introduces a new flag key in code (middleware call or `is_feature_enabled` with new key), verify a migration in the SAME PR contains `INSERT INTO feature_flag_defaults` (or equivalent seed) for that key. Missing = MUST FIX (fail-closed means dead-on-arrival in production).

9. **Notification system entry point coherence:** If a backend file in the PR writes to `in_app_notifications` or `notification_delivery_log` AND the file is NOT one of `_shared/notification-service.ts`, `notification-api/*`, `notification-purge/*`, `notification-retry/*` → MUST FIX (bypass de `emitNotificationEvent`).

10. **Shared module evasion:** Cross-reference Agent 1's findings against the `_shared/` module catalog (SHARED_REUSE section). If a flagged behavior (custom CORS, custom rate-limit, manual JWT parse, direct fetch without `fetchWithResilience`) has a canonical shared counterpart, escalate to MUST FIX with the shared path as suggested fix.

11. **Command Palette catalog coherence:** Triple cross-section combinando route + flag + i18n.
    - **Routes ↔ catalog:** Si Agent 3 (frontend) detecta nuevo `<Route path>` en `App.tsx` Y `pageCatalog` no fue modificado en el PR → MUST FIX.
    - **Flag ↔ catalog ↔ feature_flag_defaults:** Si Agent 3 detecta nuevo `useFeatureFlag('X')` que gate una seccion navegable, validar la cadena completa: (a) entry en catalog con `requiresFlag: 'X'`, (b) `'X'` en `KnownFeatureFlag` union, (c) `useDeepActionFlagMap` lo resuelve, (d) Agent 1 confirma migracion con `INSERT INTO feature_flag_defaults` para `'X'`. Falta cualquiera de los 4 → MUST FIX.
    - **i18n ↔ catalog:** Para cada entry nuevo en el catalog, verificar key existe en los 4 locales `command-palette.json` (en/es/fr/pt). Falta en cualquiera → MUST FIX.

## Step 5: Consolidate and Report

For each finding from any agent, provide:
```
[FILE:LINE] [CHECK_ID] [ISSUE] [EVIDENCE]
```

Classify each as: **MUST FIX** / **SHOULD FIX** / **CONSIDER**

### Output Format

```
## PR #{prNumber} Cross-Cutting Concerns Review

### Modules Reviewed
- {module-1}: {file count} files ({scope description})
- {module-2}: {file count} files ({scope description})

### A) Executive Summary
- **Verdict:** BLOCK / APPROVE WITH CONDITIONS / CLEAN
- **Must Fix:** N issues
- **Should Fix:** N issues
- **Consider:** N issues

### B) Security + Auth + Tenant Findings
| # | File:Line | Check | Issue | Class | Evidence |
|---|-----------|-------|-------|-------|----------|

### C) Architecture + Points + Validation Findings
| # | File:Line | Check | Issue | Class | Evidence |
|---|-----------|-------|-------|-------|----------|

### D) Frontend + i18n Findings
| # | File:Line | Check | Issue | Class | Evidence |
|---|-----------|-------|-------|-------|----------|

### E) Cross-Section Issues
| # | Type | Files Involved | Issue | Risk |
|---|------|---------------|-------|------|

Standard: {N} issues ({X} must fix, {Y} should fix, {Z} consider). {M} modules reviewed.
```

## Idioma

TODO el output debe ser en **español neutro latinoamericano**. Nombres de archivos, variables y código se mantienen en inglés. Severidades en inglés (MUST FIX, SHOULD FIX, CONSIDER).

## Notes

- `{repo}` se autodetecta desde el git remote del cwd. Override con `--repo owner/repo`.
- If the diff is too large, prioritize by the order in Step 1c.
- The manager audit (`/pr-review-audit`) is NOT included — invoke separately when the PR touches manager/department/team logic.
