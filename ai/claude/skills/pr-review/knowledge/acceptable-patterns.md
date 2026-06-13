# Known Acceptable Patterns

Este documento lista patrones que, aunque pueden parecer problemáticos, son aceptables en contextos específicos.

## Patrones Aceptables por Contexto

### 1. SQL Dinámico en Reportes Internos
**Contexto:** Reportes administrativos internos con acceso restringido
**Razón:** Flexibilidad para queries complejas sin exponer a usuarios finales
**Requisitos:**
- Validación estricta de parámetros
- Solo usuarios con rol `admin` o `internal`
- Logging de todas las queries ejecutadas

### 2. Uso de `any` en Legacy Adapters
**Contexto:** Código legacy que se está migrando gradualmente
**Razón:** Evitar refactor masivo que introduzca bugs
**Requisitos:**
- Comentario explicando por qué es temporal
- Plan de migración documentado
- No usar en código nuevo

### 3. Rate Limiting Relajado en Desarrollo
**Contexto:** Ambiente de desarrollo local
**Razón:** Facilitar testing y debugging
**Requisitos:**
- Solo cuando `NODE_ENV === 'development'`
- Nunca en staging o producción

### 4. CORS Permisivo en Desarrollo
**Contexto:** Desarrollo local con múltiples puertos
**Razón:** Facilitar desarrollo frontend/backend separados
**Requisitos:**
- Solo en desarrollo
- Configuración explícita por ambiente

### 5. Validación Parcial en Wrappers
**Contexto:** Wrappers de funciones legacy que no pueden cambiar
**Razón:** Mantener compatibilidad mientras se migra
**Requisitos:**
- Validación en la capa wrapper
- Documentación del patrón legacy

### 6. Tenant ID from user_roles (server-derived)
**Contexto:** APIs multi-tenant donde el tenant del usuario se obtiene del backend
**Razón:** `tenant_id` no viene del cliente; se obtiene de la BD/sesión por `user.id`
**Requisitos:**
- `tenantId` (o equivalente) se asigna desde una query a `user_roles` (o similar) filtrada por `user_id`/`user.id`, o desde sesión/JWT por usuario autenticado
- INSERT usa `tenant_id: tenantId` con ese valor; UPDATE/PATCH usan `.eq('tenant_id', tenantId)` (y `.eq('id', ...)`) en el WHERE
**Supresión:** No reportar IDOR por "client-supplied tenant_id", "create team/entity in another tenant's name", ni "modify/archive other tenant's resource" cuando el código cumple lo anterior

### 7. tenant_id opcional en schema compartido (JWT + service-role)
**Contexto:** Schemas Zod compartidos entre path JWT (usuario) y path service-role (interno)
**Razón:** (1) Path JWT: el tenant viene de `auth.tenantId` (token); el cliente no debe enviar `tenant_id` en el body para evitar override. (2) Path service-role: `tenant_id` es obligatorio y se valida en código (`if (!tenant_id) return 400`).
**Requisitos:**
- Schema común con `tenant_id` opcional (ej. `z.string().uuid().optional()`)
- En el handler del path service-role, validación explícita: `if (!tenant_id) return c.json(..., 400)` (o equivalente)
- Path JWT usa `auth.tenantId` para el tenant
**Supresión:** No reportar HIGH/CRITICAL por "tenant_id obligatorio" o "tenant_id debe ser requerido" en schemas de spend/refund cuando exista la validación explícita en el handler del path service-role

### 8. Seed File Data (passwords, trigger disabling, truncation)
**Contexto:** Archivos SQL seed (`*seed*.sql`) usados para desarrollo local
**Razón:** Seed data usa passwords dummy (`crypt('password123', gen_salt('bf'))`), desactiva triggers (`SET session_replication_role = 'replica'`), y trunca tablas para setup limpio. No son concerns de producción.
**Requisitos:**
- Nombre del archivo contiene "seed" y extensión `.sql`
- Patrones: passwords hardcodeadas, trigger disabling, truncation, replication role
**Supresión:** Suprimir findings CRITICAL/HIGH sobre passwords, replication role, trigger disabling en seed files.

### 9. E2E Test Helper Repetition
**Contexto:** Archivos E2E test (`.spec.ts`, `.spec.js`) y tests de integración
**Razón:** Invocaciones repetidas de helpers de setup en cada test case es práctica estándar para aislamiento de tests. Cada test debe configurar su estado independientemente para evitar acoplamiento.
**Requisitos:**
- Archivo es un test/spec file
- Finding es sobre duplicación de código, violación DRY, o patrones repetidos
**Supresión:** Suprimir findings de duplicación/DRY en archivos de test.

### 10. Domain Constants (progress thresholds, time values)
**Contexto:** Números como 25/50/75/100 (thresholds de progreso/milestones), 86400000 (ms en un día), 300 (5 min de expiración), 3000/15000 (timeouts de UI)
**Razón:** Son constantes de dominio con significado específico, no magic numbers arbitrarios. Aparecen consistentemente en el codebase con el mismo significado.
**Requisitos:**
- El valor se usa consistentemente con el mismo significado en ≥2 archivos
- El contexto hace evidente el significado (ej: threshold de progreso, timeout)
**Supresión:** Reducir a SUGGESTION o suprimir findings de "magic number" para constantes de dominio conocidas.

### 11. Standard React Form Patterns
**Contexto:** Patrones comunes en formularios React controlados
**Razón:** Son patrones idiomáticos de React, no code smells
**Requisitos:**
- Handlers onValueChange que resetean múltiples campos (lógica de formulario controlado)
- Cadenas de ternarios simples (≤3 ramas) para mapeo de valores
- Ubicación de utilidades en archivos de conveniencia (ej: isValidUUID en errors.ts)
**Supresión:** Suprimir quality/code-smell para estos patrones estándar.

### 12. SQL Migration Patterns
**Contexto:** Patrones estándar en migraciones SQL de Supabase
**Razón:** Son prácticas correctas para migraciones
**Requisitos:**
- ON CONFLICT DO UPDATE en migraciones es idempotente por diseño
- DROP VIEW + CREATE VIEW es requerido cuando se agregan columnas (limitación de PostgreSQL)
- INSERT sin verificar existencia de tabla es estándar en migraciones ordenadas
**Supresión:** Suprimir mantenibilidad/migraciones para estos patrones.

### 13. i18n defaultValue en español
**Contexto:** Proyecto usa react-i18next con `t('key', { defaultValue: 'Texto en español' })`
**Razón:** El defaultValue en español es el patrón i18n del proyecto — el texto está listo para traducción, no es "hardcoded sin i18n"
**Requisitos:**
- El componente importa `useTranslation` o `t` de react-i18next
- Los strings usan `t('key')` o `t('key', { defaultValue: '...' })`
**Supresión:** No reportar "strings hardcodeados sin i18n" cuando el componente usa `t()` con defaultValue en español.

### 14. Manager / "is org manager" — patrón canónico vs anti-patrón
**Contexto:** Cualquier gate de autorización que decida "este usuario es manager y puede X". Aplica a edge functions, RPC, frontend y RLS policies.
**Fuente de verdad:** la función Postgres `public.is_org_manager(_user_id UUID, _tenant_id UUID)` (migración `20260206152933_*.sql`). Devuelve `true` iff el usuario es `manager_id` de algún `departments` o `teams` row del tenant.

**CORRECTO (no reportar):**
- `await supabase.rpc('is_org_manager', { _user_id, _tenant_id })`
- Query directo a `departments WHERE manager_id = user_id AND tenant_id = X` o `teams WHERE manager_id = user_id AND tenant_id = X`
- Helpers que internamente delegan al RPC (ej. `validateAudienceScope` en `recognition-api/services/grant.service.ts`)
- Un futuro `_shared/org-manager.ts` que envuelva el RPC

**ANTI-PATRÓN (reportar siempre como MUST FIX):**
- `ctx.roles.includes('manager')` o `userRole.role === 'manager'` o `['admin', 'manager', 'hr'].includes(role)` usado como gate
- Helpers tipo `isAdminOrManager(ctx)` cuya implementación solo lee `roles`/`role` sin tocar `is_org_manager` ni `manager_id`
- Determinar manager por `user_roles.role='manager'` + `profiles.department_id` matchea
- Inconsistencia interna: el MISMO handler usa `is_org_manager` en un step y `roles.includes('manager')` en otro (defense-in-depth no excusa el gate inicial incorrecto)

**Justificación:** el role string `'manager'` en `user_roles` es legacy y ya no es fuente de verdad. Un usuario puede ser manager efectivo (es `departments.manager_id`) sin tener role legacy, o tener role legacy sin gestionar nada hoy. Existe test enforcing en `supabase/functions/challenge-api/__tests__/unit/security/org-manager-authorization.security.test.ts`: "Authorization must use is_org_manager RPC, not role string."

**Helper gap:** el proyecto NO tiene `_shared/org-manager.ts` — cada call site invoca el RPC inline. Cuando se detecte el anti-patrón, recomendar crear el helper junto con la corrección (ver `pr-review-audit/SKILL.md` paso 9 para el skeleton sugerido).

**Supresión:** ninguna — este patrón es siempre MUST FIX cuando aplica a un gate de autorización. Solo no reportar si el archivo NO toca autorización (ej. UI estática que muestra el role como label).

### 15. Cron migrations — patrón canónico vs operaciones inocuas
**Contexto:** Migraciones SQL que tocan pg_cron (`cron.schedule`, `cron.unschedule`, `cron.alter_job`)
**Fuente de verdad:** `docs/cron-canonical-format.md` en el repo de producto (introducido por PR #355, feature/cron-gcp). El parser `scripts/extract-cron-manifest.ts` valida el formato en CI (`pr-check.yml`).

**Formato canónico exigido (MUST FIX si falla):**
- Jobname kebab-case `[a-z0-9-]{1,63}`, único en el repo
- Schedule POSIX 5-field
- URL: `current_setting('app.settings.supabase_url', true) || '/functions/v1/<edge-function-name>'` (exacto)
- Headers via `jsonb_build_object(...)` con `Content-Type` + uno de los 3 auth headers canónicos:
  - `'x-supabase-cron', 'true'` (valor literal exacto)
  - `'x-cron-secret', current_setting('app.settings.cron_secret', true)`
  - `'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)`
- Settings namespaced `app.settings.*` (no `app.supabase_url` ni `app.service_role_key` sin namespace)
- Dollar-quoting solo `$$ ... $$` (no tagged)
- Direct-SQL job: `SELECT <schema>.<fn>(<literales>)` con schema explícito; DEBE acompañarse de update a `supabase/functions/cron-direct/index.ts` (`ALLOWED_ACTIONS`) y test

**OPERACIONES INOCUAS (NO reportar):**
- `cron.unschedule('job-name')` puro, sin reschedule posterior — limpieza legítima
- `cron.alter_job(<id>, schedule => 'X')` que cambia SOLO el schedule sin tocar URL/headers/body — cambio operacional aceptable
- `DO $$ BEGIN PERFORM cron.unschedule('name'); EXCEPTION WHEN OTHERS THEN NULL; END $$;` previo a un `cron.schedule` nuevo — patrón canónico de idempotencia para reemplazar jobs

**ANTI-PATRÓN (reportar siempre como MUST FIX o CRITICAL):**
- URL hardcoded (`https://*.supabase.co`) → MUST FIX (no portable a preview)
- Settings sin namespace (`current_setting('app.supabase_url')`, `current_setting('app.service_role_key')`) → MUST FIX (Supabase managed solo setea `app.settings.*`; sin namespace queda NULL en prod)
- Secreto hardcoded en valor de header (`'Authorization', 'Bearer eyJ...'`, `'x-cron-secret', 'literal-secret'`) → CRITICAL (token en repo público)
- Tagged dollar quotes (`$tag$ ... $tag$`) → MUST FIX (parser rechaza)
- Direct-SQL job sin update correspondiente a `cron-direct/ALLOWED_ACTIONS` → MUST FIX (cron funciona en prod pero rompe en preview)
- Edge function destino que NO valida `x-supabase-cron` ni `x-cron-secret` → MUST FIX (endpoint cron sin auth)

**Supresión:** suprimir findings sobre las 3 operaciones inocuas listadas arriba. Para todo lo demás, mantener severidad.

### 16. Sistema de notificaciones — entrada canónica vs evasión
**Contexto:** Cualquier edge function que necesite crear/actualizar/borrar notificaciones para usuarios finales.
**Fuente de verdad:** `_shared/notification-service.ts` expone `emitNotificationEvent()` que orquesta: feature-flag check (`notifications_enabled` per tenant) → preference check (`check_notification_preference` RPC) → insert + dispatch a canales (in-app, email).

**CORRECTO (no reportar):**
- Llamadas a `emitNotificationEvent()` desde cualquier edge function de negocio
- INSERT/UPDATE/DELETE directo a `in_app_notifications` o `notification_delivery_log` desde: `_shared/notification-service.ts`, `notification-api`, `notification-purge`, `notification-retry` (estas funciones SON el sistema de notificaciones, no consumidoras)
- Queries SELECT sobre `in_app_notifications` desde cualquier edge function (listar para mostrar al usuario, contar unread)

**ANTI-PATRÓN (reportar como MUST FIX):**
- Edge function de negocio (recognition-api, challenge-api, ecards-api, etc.) que hace `INSERT INTO in_app_notifications` directo en vez de `emitNotificationEvent`
- Edge function que hace HTTP POST a `notification-api` desde otra edge function (cross-function HTTP coupling — usar el shared)
- PR que crea una tercera tabla con semántica de notificación (`*_notifications`, `*_messages`, `user_alerts`) en vez de extender `in_app_notifications`

**Acoplamiento legacy aceptable (mientras no haya refactor):**
- `_shared/notification-service.ts` importa de `notification-api/services/notification-tracker.ts` — acoplamiento conocido, refactor pendiente. NO flaggear hasta que haya ticket de migración.

**Supresión:** suprimir findings sobre operaciones legítimas listadas en CORRECTO. Mantener severidad MUST FIX para evasión real.

### 17. Reuso de módulos `_shared/` — canónicos vs reimplementación
**Contexto:** PRs que agregan nueva funcionalidad en edge functions donde ya existe un módulo `_shared/` canónico con esa responsabilidad.
**Razón:** Reimplementar `_shared/` divergente introduce: (1) drift de seguridad (el canónico tiene tests y observabilidad), (2) bugs duplicados, (3) inconsistencia operacional. La regla SHARED_REUSE del CCC exige justificación explícita.

**Catálogo de módulos canónicos (al 2026-05-18):**

| Módulo | Responsabilidad | Evasión típica = MUST FIX |
|---|---|---|
| `_shared/cors.ts` | CORS middleware (Hono) + headers (legacy) | `'Access-Control-Allow-Origin': '*'` hardcoded en respuesta |
| `_shared/observability-middleware.ts` | trace_id, latency log estructurado | edge function sin `app.use('*', observabilityMiddleware)` + `console.log` ad-hoc |
| `_shared/storage-adapter/` | upload/download/remove (preview ↔ prod path mapping) | `admin.storage.from(...).{remove,upload}` directo |
| `_shared/rate-limit.ts` | RPC fail-closed rate-limit | nueva implementación con interfaz incompatible |
| `_shared/notification-service.ts` | `emitNotificationEvent` (ver §16) | INSERT directo a `in_app_notifications` |
| `_shared/integration-utils.ts` | `fetchWithResilience` (retries + correlationId) | `fetch()` directo a DDM / gestion-puntos / apprecio-identity |
| `_shared/auth-utils.ts` | parse JWT, derivar `auth` context | parseo manual de JWT con `jose` o split bearer |
| `_shared/recognition-service.ts` | `grantRecognitionInternal` | INSERT directo a `recognition_transactions` |

**Excepciones aceptables (no reportar):**
- El módulo shared NO existe todavía (gap real, e.g., `_shared/cron-auth.ts`, `_shared/lock-utils.ts`, `_shared/org-manager.ts`). En este caso recomendar crear el shared en este PR o crear ticket de followup — no es una "evasión".
- El PR documenta explícitamente por qué el shared no aplica (contrato diferente, perfomance, semántica de dominio). La justificación debe estar en el body del PR o en comment inline.
- Tests: archivos de test pueden reimplementar fixtures locales sin pasar por shared.

**Cross-function HTTP coupling (caso especial, SHOULD FIX):**
Una edge function NO-`_shared/` importando directo de OTRA edge function (e.g., `_shared/notification-service.ts` importando de `notification-api/services/notification-tracker.ts`, o `awards-api` importando de `recognition-api/services/...`) indica que la lógica compartida debería estar en `_shared/`. Reportar como SHOULD FIX con sugerencia de refactor.

**Supresión:** suprimir findings de "evasión shared" cuando aplica una excepción documentada. Mantener MUST FIX para evasiones sin justificación.

### 18. Command Palette catalog — sync obligatorio vs rutas que NO van al catalog
**Contexto:** PRs que tocan rutas, tabs deep-linkables, modales URL-disparables, feature flags de navegación o kill-switches.
**Fuente de verdad:** `src/components/command-palette/catalog.ts` (introducido por PRs #206/#208/#210, consolidados en trunk closer #215). PR #359 documentó la decisión cross-cutting de 2026-05-18: cada PR que afecta navegación actualiza el catalog en el MISMO PR — no hay ticket separado.

**REGLA GENERAL:** toda ruta admin-accesible nueva DEBE tener entry en `pageCatalog` o `actionCatalog`, con `labelKey` traducido en los 4 locales (`en/es/fr/pt/command-palette.json`), y `requiresFlag` cuando aplica un gate de feature.

**RUTAS QUE NO VAN AL CATALOG (no reportar como "ruta sin entry"):**
- **Rutas privadas no-admin:** `/auth/login`, `/auth/signup`, `/auth/reset-password`, `/onboarding/*`, rutas públicas del tenant — el catalog es admin-only (`useCommandPaletteAccess` exige `isAdmin && command_palette_enabled`)
- **Rutas de detalle dinámicas:** `/usuarios/:id`, `/reconocimientos/:id`, `/equipos/:teamId`, cualquier ruta con segmento `:param` — el palette indexa entry points, no instancias
- **Rutas internas/debug:** `/_debug/*`, `/__internal/*`, `/dev/*`
- **PR-6l Hybrid:** páginas dedicadas que se eliminaron del sidebar PERO siguen siendo indexables vía palette son aceptables — Command Palette SÍ indexa pages dedicadas aunque NO estén en sidebar (decisión documentada en PR #359). NO reportar "ruta sin entry" en este caso si la entry existe en catalog.

**OPERACIONES INOCUAS (no reportar):**
- PR que solo renombra archivos (paths internos) sin cambiar URLs públicas
- PR que solo cambia markup interno de una página existente, sin agregar tab/modal deep-linkable nuevo
- PR que solo agrega/cambia tests E2E del catalog (`tests/e2e/command-palette/*.spec.ts`)
- PR que solo actualiza i18n del catalog para traducciones FR/PT existentes en ES/EN
- Borrado de entry porque la ruta se eliminó intencionalmente (siempre que la ruta también se borre del router)

**ANTI-PATRÓN (reportar como MUST FIX):**
- Nueva `<Route path="/X">` en `App.tsx` admin-accesible y NO ausente del `pageCatalog` → entry zombi invisible
- Entry con `url` que NO resuelve a ruta válida en `App.tsx` (ruta renombrada/borrada sin update del catalog) → click navega a 404
- Sección con `useFeatureFlag('X')` que gate render Y entry SIN `requiresFlag: 'X'` → entry visible cuando flag OFF, click va a página vacía
- Entry con `requiresFlag: 'X'` donde `'X'` no está en `KnownFeatureFlag` union → TS error en cliente
- Entry con `labelKey: 'pages.X'` que NO existe en uno o más de `en/es/fr/pt/command-palette.json` → key literal renderizada en producción
- Kill-switch nuevo (default-ON, disable módulo) para módulo navegable SIN agregar `requiresFlag` del kill-switch a las entries del módulo → módulo apagado pero descubrible vía palette

**Supresión:** suprimir findings de "ruta sin entry" cuando la ruta cae en alguna categoría de "no van al catalog". Mantener MUST FIX para los anti-patrones reales.

## Supresión de Findings

Si un finding reporta un patrón listado aquí, debe ser:
1. Verificado que cumple los requisitos del patrón aceptable
2. Si cumple: reducir severidad a SUGGESTION o suprimir
3. Si no cumple: mantener severidad original

## Ejemplos de Supresión

- `any` en `legacy/adapters/oldApi.ts` → SUGGESTION (si tiene comentario explicativo)
- SQL dinámico en `admin/reports.ts` → SUGGESTION (si valida parámetros)
- Rate limiting ausente en `dev-only.ts` → SUGGESTION (si está en desarrollo)
- IDOR "client-supplied tenant_id" o "create/update en otro tenant" cuando `tenantId` viene de `user_roles` por `user.id` → NO reportar (ver patrón 6)
- "tenant_id obligatorio" en `spend.schema.ts` / `RefundRequestSchema` cuando el handler tiene `if (!tenant_id) return 400` en path service-role → NO reportar (ver patrón 7)

<!-- AUTO-GENERATED: DO NOT EDIT BELOW THIS LINE -->
## Patrones Aprendidos Automáticamente (2026-03-23)

> Generado desde 4 patrones con confianza ≥ 85% y tasa de FP ≥ 80%.
> Ejecutar `scripts/sync-acceptable-patterns.ts` para actualizar.

### A1. Alta tasa de falsos positivos para categoría "seguridad/idor" en ivaldovinos-app/apprecio-pulse
**Categoría:** seguridad/idor
**Tasa de FP:** 100% (49 casos, confianza 90%)
**Aprendido:** 2026-03-23
**Archivos de origen:** ivaldovinos-app/apprecio-pulse
**Supresión:** Reducir a SUGGESTION o suprimir cuando el código coincide con este patrón.

### A2. Alta tasa de falsos positivos para categoría "seguridad/cors" en ivaldovinos-app/apprecio-pulse
**Categoría:** seguridad/cors
**Tasa de FP:** 100% (20 casos, confianza 90%)
**Aprendido:** 2026-03-23
**Archivos de origen:** ivaldovinos-app/apprecio-pulse
**Supresión:** Reducir a SUGGESTION o suprimir cuando el código coincide con este patrón.

### A3. Alta tasa de falsos positivos para categoría "quality/code-smell" en ivaldovinos-app/apprecio-pulse
**Categoría:** quality/code-smell
**Tasa de FP:** 100% (24 casos, confianza 90%)
**Aprendido:** 2026-03-23
**Archivos de origen:** ivaldovinos-app/apprecio-pulse
**Supresión:** Reducir a SUGGESTION o suprimir cuando el código coincide con este patrón.

### A4. Alta tasa de falsos positivos para categoría "seguridad/cors" en ivaldovinos-app/apprecio-pulse
**Categoría:** seguridad/cors
**Tasa de FP:** 100% (73 casos, confianza 90%)
**Aprendido:** 2026-03-23
**Archivos de origen:** ivaldovinos-app/apprecio-pulse
**Supresión:** Reducir a SUGGESTION o suprimir cuando el código coincide con este patrón.

### A5. Health endpoint CORS/auth permissive
**Categoría:** security/cors, quality/code-smell
**Tasa de FP:** 100% (confirmado en PR #86)
**Aprendido:** 2026-03-26
**Descripción:** CORS wildcard (*) en endpoints de health/monitoring (/health, /healthz, /status, /ping) es práctica estándar. Estos endpoints son intencionalmente públicos y no manejan datos sensibles.
**Supresión:** Suprimir findings de seguridad/CORS en endpoints de health/monitoring.

### A6. SQL injection con input numéricamente validado
**Categoría:** security/injection, quality/code-smell
**Tasa de FP:** 100% (confirmado en PR #86)
**Aprendido:** 2026-03-26
**Descripción:** Interpolación directa de variables en SQL no es un riesgo si el input fue validado estrictamente antes del uso (ej: `[[ "$VAR" =~ ^[0-9]+$ ]]`, `parseInt()`, Zod schema).
**Supresión:** Suprimir findings de injection cuando hay validación previa del input en las 30 líneas anteriores.

### A7. Global middleware auth coverage
**Categoría:** security/auth
**Tasa de FP:** 100% (confirmado en PR #91)
**Aprendido:** 2026-04-19
**Descripción:** Edge functions con `app.use('*', authMiddleware)` aplican auth a todas las rutas. Reportar "missing auth on route" o "sub-flag without master flag" cuando middleware global ya lo cubre es falso positivo.
**Supresión:** Verificar `index.ts` del edge function por `app.use('*', ...)` antes de reportar.

### A8. Internal server-to-server services
**Categoría:** security/auth, security/idor
**Tasa de FP:** 100% (confirmado en PR #91)
**Aprendido:** 2026-04-19
**Descripción:** Archivos en `_shared/*-service.ts` son llamados por edge functions, no por HTTP clients. El caller ya validó JWT y derivó tenantId.
**Supresión:** Suprimir "tenantId not validated vs JWT" para servicios internos `_shared/`.

### A9. Backend API validation messages in English
**Categoría:** quality/i18n
**Tasa de FP:** 100% (confirmado en PR #91)
**Aprendido:** 2026-04-19
**Descripción:** Mensajes de validación Zod en edge functions son consumidos por API clients (frontend, mobile), no por usuarios finales. Mensajes en inglés son práctica estándar.
**Supresión:** Solo reportar i18n para strings user-facing en `.tsx`. No reportar mensajes Zod en backend.

### A10. Test files not in CI glob path (phantom tests)
**Categoría:** quality/ci-coherence
**Tasa de FP:** 0% (confirmado en PR #104)
**Aprendido:** 2026-04-29
**Descripción:** Test files que existen en el repo pero no son ejecutados por ningún workflow de CI porque su path no coincide con los globs de `deno test` / `vitest` / `jest`. Ejemplo: tests en `__tests__/*.test.ts` cuando CI espera `__tests__/unit/**/*.test.ts`. Estos tests dan falsa sensación de cobertura — pasan "code review" pero nunca corren en el pipeline.
**Detección:** Comparar paths de `*.test.ts` / `*.spec.ts` en el PR contra los globs en `.github/workflows/backend-tests.yml` (campo `deno test`) y workflows equivalentes.
**Severidad:** MUST FIX — tests fantasma son peores que no tener tests porque impiden detectar regresiones.

<!-- END AUTO-GENERATED -->
