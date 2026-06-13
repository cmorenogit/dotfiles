# Detection Rules — índice y triggers

Reglas de detección específicas de dominio para `apprecio-pulse`. Diferente de:
- `../acceptable-patterns.md` — anti-FP transversal (qué NO flaggear)
- `../iteration-contract.md` — proceso de revisión (cuándo aprobar)

Estas son **reglas positivas**: dado un patrón de código, qué severidad asignar y por qué.

## Cómo se consumen

Cada regla declara:
- **Trigger**: patrones de archivo / símbolos en el PR que activan la regla
- **Skills que la consumen**: cuál subagente debe cargarla (G2/G3/CCC/audit/etc.)
- **Severidades**: qué patrones reporta y con qué severidad

Flujo en `pr-review/SKILL.md` Step 0.6:
1. Listar archivos del PR.
2. Para cada regla en este directorio, evaluar trigger.
3. Si match → cargar la regla y pasarla como detection rule al subagente que la consume.

Si el trigger no matchea, la regla NO se carga (ahorra tokens del subagente).

## Reglas vigentes

| Regla | Archivo | Trigger (resumen) | Consumida por |
|-------|---------|--------------------|---------------|
| **Economic grants — otorgamiento de puntos económicos** | [`economic-grants.md`](./economic-grants.md) | Archivos que tocan `point_transactions`, `wallet_ledger`, `grant_economic`, `grant_recognition`, `grant_xp`, `grant_mission_economic`, o cualquier edge function `*-grant*` / `*economic*` | G2 (Auth+IDOR+Manager) + CCC (cross-cutting) |
| **Migration timestamps — colisiones y orden** | [`migration-timestamps.md`](./migration-timestamps.md) | PR añade archivos en `supabase/migrations/*.sql` con prefix `YYYYMMDDHHMMSS_` | G3 (SQL+RLS+Cron) + CCC |

## Convenciones para añadir una regla nueva

Cada archivo de regla sigue este template:

```markdown
# <Nombre del dominio> — <una línea de propósito>

## Trigger
<file patterns / símbolos que activan la regla>

## Skills que la consumen
<G1/G2/G3/G4/G5/CCC/audit/tests/scope>

## Regla vigente
<estado actual del repo, lo que SÍ flaggear hoy>

### Severidades
| Patrón | Severidad | Razón |
|--------|-----------|-------|
| ... | MUST FIX / WARN / SUGGESTION | ... |

## Regla target (si aplica)
<estado deseado, lo que se está migrando hacia>

## Anti-FP claves
<qué NO flaggear — patrones que se ven similares pero son válidos>

## Ejemplos verificables
<código de ejemplo "correcto" y "incorrecto" con paths reales>

## Historia / contexto (opcional)
<por qué la regla existe, incidentes que la motivaron, PRs ground-truth>
```

Después de añadir una regla nueva:
1. Actualizar la tabla de "Reglas vigentes" arriba.
2. Si el trigger debe modificar SKILL.md (ej. nueva detección en G2), actualizar también esa skill.

## Convenciones de severidad

Las severidades usadas en este directorio se alinean con `pr-review/SKILL.md`:
- **MUST FIX** = bloquea merge bajo bar `MUST-FIX-or-above` o equivalente. Es un bug real, no estilo.
- **WARN / SHOULD FIX** = no bloquea por sí solo, pero acumulado o en contexto sensible sí. Se reporta y entra a Quick Wins si aplica.
- **SUGGESTION / CONSIDER** = mejora opcional o deuda diferible.

Cómo el bar del trunk decide qué de esto bloquea está en `../iteration-contract.md` Regla 2.
