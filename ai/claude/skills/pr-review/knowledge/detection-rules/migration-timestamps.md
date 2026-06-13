# Migration timestamps — colisiones y orden en `supabase/migrations/`

Supabase aplica migraciones por orden alfanumérico del prefix `YYYYMMDDHHMMSS_` y registra cada una en `schema_migrations` por **version** (el prefix exacto). Tres patrones de PR rompen este modelo de forma silenciosa: timestamps duplicados, timestamps fuera de orden respecto a `main`, y timestamps en el futuro.

Estos bugs no fallan en CI (lint, types, tests pueden pasar) — se descubren al hacer `supabase db push` en preview o en producción cuando el efecto ya es tarde.

## Trigger

Activar esta regla si el PR añade o renombra archivos bajo:
- `supabase/migrations/*.sql`

No aplica a:
- Modificaciones de migraciones existentes (no se cambia el prefix)
- Archivos fuera de `supabase/migrations/`
- `*.md` o `*.json` de documentación de migración

## Skills que la consumen

- **G3** (SQL + RLS + Cron) — verificación principal
- **CCC** (Cross-cutting concerns) — para PRs grandes que tocan múltiples módulos con migraciones en cada uno

## Regla vigente

### Severidades

| Patrón detectado | Severidad | Cómo verificar |
|------------------|-----------|----------------|
| **Colisión intra-PR**: dos archivos del mismo PR con prefix `YYYYMMDDHHMMSS_*.sql` idéntico | **MUST FIX** | `ls` o `git diff --name-only main...HEAD -- 'supabase/migrations/*.sql' \| awk -F'_' '{print $1}' \| sort \| uniq -d` |
| **Colisión inter-branch**: un prefix del PR coincide con uno ya presente en `main` | **MUST FIX** | Comparar la lista de prefixes del PR con `gh api repos/{repo}/contents/supabase/migrations?ref=main --jq '.[].name'` |
| **Out-of-order**: el timestamp del PR es **menor** que el max timestamp en `main` | **MUST FIX** | Tomar `max(timestamps en main)` y comparar contra cada timestamp del PR |
| **Timestamp futuro** (> hoy + 30 días) | **WARN** | Comparar contra `date +%Y%m%d%H%M%S` y `date +%Y%m%d%H%M%S -d '+30 days'` (o equivalente) |
| **Formato inválido** (no es `[0-9]{14}_*.sql`) | **MUST FIX** | Regex match contra `^[0-9]{14}_.*\.sql$` |

### Por qué cada uno es bloqueante

**Colisión intra-PR:** Cuando el CLI de Supabase procesa migraciones, dos archivos con el mismo version causan comportamiento no determinista. Algunas versiones del CLI aplican solo el primero alfanumérico, otras fallan. Si el equipo usa `supabase db push --include-all`, puede aplicarse solo uno y el otro queda "marcado como aplicado" sin ejecutarse — silent skip que llega a producción.

**Colisión inter-branch:** El bug clásico. PR-A se mergea con migración `20260525120000_foo.sql`. Tu PR-B (creado antes de PR-A) tiene `20260525120000_bar.sql`. Cuando tu PR se mergea, Supabase ve la version `20260525120000` ya registrada en `schema_migrations` y **no la reaplica**. `bar.sql` nunca se ejecuta — pero TypeScript types ya importan el schema esperado y el código falla en runtime.

**Out-of-order:** PR-A mergeó `20260525120000_foo.sql`. Tu PR tiene `20260524180000_bar.sql` (un día menos). Supabase aplica en orden de version: ya pasó por `20260524180000` (nunca lo vio, pero el max aplicado es mayor) y al ejecutar `db push` tu migración **queda sin aplicar**. Esto es especialmente fácil de producir cuando dos devs trabajan en branches paralelas que se hicieron antes y mergean en orden inverso.

**Timestamp futuro:** Típicamente typo (`20270525...` por `20260525...`). No bloquea ahora pero envenena el orden: futuras migraciones legítimas pueden no aplicarse porque el prefix futuro ya marca el "max" en `schema_migrations`. Difícil de detectar sin esta regla.

## Anti-FP claves — NO confundir con patrones válidos

- **Renombre de una migración existente** entre branches (mismo contenido, mismo prefix) durante rebase: no es colisión, es resolución de merge. La regla solo aplica a archivos **nuevos** en el PR (`gh api ... files` con status `added`, no `renamed` sin cambio de prefix).
- **Múltiples migraciones del MISMO PR con prefixes distintos** (`20260525120000_a.sql`, `20260525130000_b.sql`): válido. La regla detecta duplicados de prefix, no múltiples migraciones.
- **Migración con prefix muy antiguo en un PR de fix** (ej. bugfix retroactivo a una migración legacy): sospechoso, **WARN no MUST FIX**. Confirmar con el dev: ¿es realmente un fix retroactivo a una DB ya en producción, o un typo?
- **Repos que NO usan timestamps** (ej. nombres tipo `001_init.sql`, `002_users.sql`): regla no aplica. El trigger asume formato `YYYYMMDDHHMMSS_*`. Verificar con `ls supabase/migrations | head -5` antes de aplicar.

## Verificación rápida en code review

```bash
# 1. Listar timestamps añadidos en el PR
PR_TIMESTAMPS=$(gh pr view {prNumber} -R {repo} --json files --jq '.files[].path' \
  | grep '^supabase/migrations/.*\.sql$' \
  | awk -F'/' '{print $NF}' \
  | grep -oE '^[0-9]{14}')

# 2. Detectar colisión intra-PR
echo "$PR_TIMESTAMPS" | sort | uniq -d  # si imprime algo → MUST FIX

# 3. Listar timestamps en main
MAIN_TIMESTAMPS=$(gh api "repos/{repo}/contents/supabase/migrations?ref=main" \
  --jq '.[].name' \
  | grep -oE '^[0-9]{14}')

# 4. Detectar colisión inter-branch (intersect PR ∩ main)
comm -12 <(echo "$PR_TIMESTAMPS" | sort -u) <(echo "$MAIN_TIMESTAMPS" | sort -u)  # si imprime algo → MUST FIX

# 5. Detectar out-of-order
MAIN_MAX=$(echo "$MAIN_TIMESTAMPS" | sort -n | tail -1)
echo "$PR_TIMESTAMPS" | awk -v max="$MAIN_MAX" '$1 < max {print "OUT-OF-ORDER: " $1 " < " max}'

# 6. Detectar timestamps futuros (más de 30 días)
NOW=$(date -u +%Y%m%d%H%M%S)
FUTURE_LIMIT=$(date -u -v+30d +%Y%m%d%H%M%S 2>/dev/null || date -u -d '+30 days' +%Y%m%d%H%M%S)
echo "$PR_TIMESTAMPS" | awk -v limit="$FUTURE_LIMIT" '$1 > limit {print "FUTURE: " $1}'
```

(Para macOS, `date -v+30d`; para Linux, `date -d '+30 days'`. La regla acepta cualquiera.)

## Ejemplos verificables

### MUST FIX — Colisión intra-PR

```
supabase/migrations/
├── 20260525120000_add_user_preferences.sql   ← añadido en el PR
└── 20260525120000_add_audit_log.sql           ← también añadido en el PR
```

**Por qué falla:** los dos comparten version `20260525120000`. Supabase aplica uno (no determinístico) y registra la version como aplicada — el otro **nunca se ejecuta** pero queda registrado.

**Fix:** renombrar el segundo a un timestamp posterior:
```
20260525120000_add_user_preferences.sql
20260525120001_add_audit_log.sql
```

### MUST FIX — Colisión inter-branch

```
# En main (mergeado el día anterior):
supabase/migrations/20260525120000_add_indexes.sql

# En este PR:
supabase/migrations/20260525120000_add_audit_log.sql
```

**Por qué falla:** cuando este PR se mergee, `schema_migrations` ya tiene `20260525120000` registrado por la migración de main. La migración del PR queda silent-skipped en `db push`.

**Fix:** renombrar a timestamp posterior al actual max en main:
```bash
# Encontrar el max en main
gh api "repos/{repo}/contents/supabase/migrations?ref=main" --jq '.[].name' | sort | tail -3
# Renombrar la migración del PR
git mv 20260525120000_add_audit_log.sql 20260525130000_add_audit_log.sql
```

### MUST FIX — Out-of-order

```
# En main:
supabase/migrations/20260601000000_latest_main.sql    ← max actual

# En este PR (creado hace días, ahora desactualizado):
supabase/migrations/20260525120000_my_change.sql       ← timestamp menor al max
```

**Por qué falla:** `20260525120000 < 20260601000000`. Supabase ya pasó del max, no vuelve atrás. El PR se mergea, `db push` no aplica la migración (mismo silent skip).

**Fix:** rebase + renombrar al timestamp actual:
```bash
git mv 20260525120000_my_change.sql $(date -u +%Y%m%d%H%M%S)_my_change.sql
```

### WARN — Timestamp futuro

```
supabase/migrations/20270525120000_feature.sql
```

(Hoy es 2026-05-25. El timestamp es un año en el futuro.)

**Por qué warn:** probablemente typo. Si se mergea, futuras migraciones legítimas en 2026 quedarán out-of-order respecto a este timestamp falso.

**Fix:** corregir al año/mes actual.

## Historia / contexto

- **Patrón recurrente reportado por @ivaldovinos (2026-05-25):** múltiples incidentes en apps con Supabase donde el reviewer/dev no detectó colisión o out-of-order hasta que `db push` falló en preview (o peor, en producción). El bug es invisible en CI normal porque tests usan migraciones mockeadas o no validan el orden real.
- **Causa raíz:** el CLI de Supabase no advierte sobre estos patrones al crear una migración (`supabase migration new`) — siempre genera timestamp con hora actual sin verificar contra `main`. Cuando dos devs trabajan en branches paralelas, ambos generan timestamps válidos en aislamiento pero colisionan al converger.
- **Mitigación durable:** además de esta detection-rule en review, considerar pre-commit hook que valide localmente contra `main` (no parte de este repo, pero recomendado por dev experience).

## Sugerencia operativa para el dev (incluir en el report)

Si la regla dispara, sugerir el comando exacto de fix en el report:

```markdown
**Fix sugerido:** rebase contra main y renombrar la migración:
\`\`\`bash
git fetch origin main
NEW_TS=$(date -u +%Y%m%d%H%M%S)
git mv supabase/migrations/<old_ts>_<name>.sql supabase/migrations/${NEW_TS}_<name>.sql
git commit -am "fix(migration): bump timestamp to avoid collision with main"
\`\`\`
```

Esto convierte el finding en un Quick Win de < 2 minutos.
