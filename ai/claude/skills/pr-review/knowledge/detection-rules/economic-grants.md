# Economic grants — otorgamiento de puntos económicos

Toda asignación de puntos económicos a un usuario DEBE pasar por `grant_economic` RPC. El RPC contiene `governance_evaluate` internamente — cualquier caller que lo use queda gobernado automáticamente. Esta regla protege la consistencia del modelo tridimensional (economic / recognition / xp) y previene bypasses del governance layer.

## Trigger

Activar esta regla si el PR toca cualquiera de:

**Tablas:**
- `point_transactions` (lectura o escritura)
- `wallet_ledger` (lectura o escritura)

**RPCs SQL:**
- `grant_economic`
- `grant_recognition`
- `grant_xp`
- `grant_mission_economic`
- Cualquier RPC con nombre `grant_*` o `*_grant`

**Edge functions:**
- `economic-grant`
- Cualquier edge function con `grant`, `economic`, `wallet`, o `reward` en el nombre
- `reward-redemption`, `gift-card-*`, `wallet-funding-*`

**Strings en diff:**
- `INSERT INTO point_transactions`
- `INSERT INTO wallet_ledger`
- `.from('point_transactions')`, `.from('wallet_ledger')`
- `.rpc('grant_economic')`, `.rpc('grant_recognition')`, `.rpc('grant_xp')`
- `fetch(getEdgeFunctionUrl('economic-grant'))` y variantes

## Skills que la consumen

- **G2** (Auth + IDOR + Manager) — porque governance es parte del modelo de permisos
- **CCC** (Cross-cutting concerns) — porque el patrón cruza edge functions, RPCs SQL, y servicios `_shared`
- **pr-review-audit** — si el PR toca lógica de manager, manager-by-role check puede interactuar con governance

## Regla vigente (G2 actual)

### Callers válidos para grants

1. **`fetch('economic-grant')`** — orchestrator completo:
   - rate limit
   - candados del modelo tridimensional
   - DDM (Dimension Decision Matrix) sync
   - governance via `evaluateGovernanceOrThrow`
   - llama internamente a `grant_economic` RPC

2. **`.rpc('grant_economic')` directo** — funcional pero degradado:
   - governance aplica (está dentro del RPC)
   - PIERDE rate limit, candados, DDM sync
   - Aceptable solo para callers internos / RPCs SQL que ya están dentro de un flujo gobernado

### Severidades

| Patrón detectado | Severidad | Razón |
|------------------|-----------|-------|
| `INSERT INTO point_transactions` directo (en SQL migration, RPC, o edge function) para **otorgamiento** | **MUST FIX** | Bypasea governance, candados, DDM. Debe usar `grant_economic` (si es RPC SQL interno) o `fetch('economic-grant')` (si es edge function). |
| `.from('point_transactions').insert(...)` desde edge function para otorgamiento | **MUST FIX** | Mismo bypass. |
| `.rpc('grant_economic')` directo desde edge function nueva | **WARN / SHOULD FIX** | Funciona (governance OK) pero pierde rate limit + candados + DDM. Preferir `fetch('economic-grant')` para callers nuevos. |
| Nuevo RPC SQL que inserta en `point_transactions` sin llamar a `grant_economic` internamente | **MUST FIX** | Patrón de `grant_mission_economic` legacy. Debe migrarse o llamar al RPC canonical. |
| Edge function `*-grant*` o `*economic*` que NO termina llamando a `grant_economic` o `fetch('economic-grant')` | **MUST FIX** | Probablemente bypass directo. Verificar la cadena. |

## Regla target (post-normalización, issue pendiente)

Estado deseado al cerrar el effort de normalización:

- Todo caller económico usa `fetch('economic-grant')`. Sin excepciones.
- `.rpc('grant_economic')` directo queda **deprecated** para edge functions.
- RPCs SQL internos que otorgan economic deben llamar `grant_economic` internamente, no insertar directo.
- En PRs nuevos, `.rpc('grant_economic')` directo desde edge function sube de WARN → MUST FIX una vez declarado el deprecation.

Cuando el effort se complete, esta regla se actualiza para reflejar la regla target como vigente.

## Anti-FP claves — NO confundir consumo con grant

Los flujos de **CONSUMO** (debitar wallet, no otorgar) son **diferentes** de los grants y tienen una regla distinta:

### Flujos de consumo válidos (NO aplicar regla de grant)

| Flujo | Tabla | Patrón válido |
|-------|-------|----------------|
| `reward-redemption` | `wallet_ledger` (DELTA negativo) | INSERT directo a `wallet_ledger` con governance a nivel caller (`evaluateGovernanceOrThrow` antes del INSERT) |
| `gift-card-sends` | `wallet_ledger` (DELTA negativo) | INSERT directo a `wallet_ledger` con governance a nivel caller |
| `wallet-funding-create` | `wallet_ledger` (DELTA positivo de recarga, NO grant) | INSERT directo con governance a nivel caller |

**Razón:** son flujos donde el usuario DEBITA su wallet (gasta puntos) o RECARGA (admin top-up), no recibe puntos como recompensa por actividad. El trigger G1.5 en `wallet_ledger` es defense-in-depth adicional, no la única protección.

### Cómo distinguir grant vs consumo en code review

Pregúntate, viendo el INSERT/RPC:

1. **¿La tabla destino es `point_transactions` o `wallet_ledger`?**
   - `point_transactions` → casi siempre es **grant**, aplicar regla.
   - `wallet_ledger` → puede ser grant o consumo, sigue al paso 2.

2. **¿El DELTA es positivo y se origina por una acción del sistema (recompensa por actividad, badge, premio, mission)?**
   - Sí → **grant**, aplicar regla.
   - No → **consumo / recarga**, NO aplicar regla, verificar que tenga governance caller.

3. **¿El caller tiene `evaluateGovernanceOrThrow` antes del INSERT?**
   - Sí + es consumo → válido.
   - No + es consumo → **MUST FIX** distinto: falta governance a nivel caller.
   - No + es grant → **MUST FIX** por esta regla.

### Patrones específicos que NO se flaggean

- `INSERT INTO wallet_ledger` desde `reward-redemption/index.ts` con DELTA negativo y governance previa → válido.
- `INSERT INTO wallet_ledger` desde `gift-card-sends/index.ts` con DELTA negativo y governance previa → válido.
- `INSERT INTO wallet_ledger` desde `wallet-funding-create` con DELTA positivo (admin top-up) y governance previa → válido.

## Ejemplos verificables

### MUST FIX — INSERT directo a `point_transactions` para grant

```typescript
// supabase/functions/some-new-feature/index.ts — MUST FIX
const { error } = await supabase
  .from('point_transactions')
  .insert({
    user_id: userId,
    points: 100,
    dimension: 'economic',
    reason: 'feature_completed',
  });
```

**Por qué falla:** bypasea `grant_economic` RPC, no llama governance, no respeta candados ni DDM.

**Fix:**
```typescript
const grantResponse = await fetch(
  getEdgeFunctionUrl('economic-grant'),
  {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ user_id: userId, points: 100, reason: 'feature_completed' }),
  }
);
```

### WARN — `.rpc('grant_economic')` directo desde edge function nueva

```typescript
// supabase/functions/some-new-feature/index.ts — WARN
const { error } = await supabase.rpc('grant_economic', {
  _user_id: userId,
  _points: 100,
  _reason: 'feature_completed',
});
```

**Por qué warn:** governance aplica (está dentro del RPC), pero pierde rate limit, candados, DDM sync que sí provee `economic-grant` edge function.

**Recomendación:** migrar a `fetch('economic-grant')` salvo justificación documentada.

### MUST FIX — nuevo RPC SQL que inserta en `point_transactions`

```sql
-- supabase/migrations/20260601000000_new_reward_rpc.sql — MUST FIX
CREATE FUNCTION public.grant_special_bonus(_user_id uuid, _points int)
RETURNS void AS $$
BEGIN
  INSERT INTO point_transactions (user_id, points, dimension, reason)
  VALUES (_user_id, _points, 'economic', 'special_bonus');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Por qué falla:** mismo problema que `grant_mission_economic` legacy. Bypasea governance.

**Fix:**
```sql
CREATE FUNCTION public.grant_special_bonus(_user_id uuid, _points int)
RETURNS void AS $$
BEGIN
  PERFORM public.grant_economic(_user_id, _points, 'special_bonus');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Válido (NO flaggear) — INSERT a `wallet_ledger` para consumo

```typescript
// supabase/functions/reward-redemption/index.ts — VÁLIDO
await evaluateGovernanceOrThrow(ctx, 'reward_redemption', { amount });
const { error } = await supabase
  .from('wallet_ledger')
  .insert({
    user_id: userId,
    delta: -amount,  // ← DELTA negativo = consumo
    reason: 'reward_redemption',
  });
```

**Por qué válido:** es flujo de consumo (DELTA negativo), tiene governance a nivel caller, trigger G1.5 hace defense-in-depth.

## Historia / contexto

- **Bug INC-08 (2026-04):** `grant_mission_economic` insertaba directo a `point_transactions` sin pasar por governance. Permitía a missions otorgar puntos económicos saltándose candados del modelo tridimensional. Fix vía migración que reescribió el RPC para llamar `grant_economic` internamente.
- **PR #6r (decision-log 2026-05-18):** se decidió que la regla target es `fetch('economic-grant')` para todos los callers nuevos. `.rpc('grant_economic')` queda como puente hasta que se migren todos los call sites existentes.
- **Trigger G1.5 en `wallet_ledger`:** defense-in-depth posterior a INC-08. Bloquea INSERT sin governance context. NO sustituye la regla — es backstop.

## Verificación rápida en code review

Si el PR tiene cambios en algún archivo del trigger, ejecutar:

```bash
gh pr diff {prNumber} -R {repo} | grep -nE "INSERT INTO (point_transactions|wallet_ledger)|\.from\('(point_transactions|wallet_ledger)'\)|\.rpc\('grant_(economic|recognition|xp)'\)|getEdgeFunctionUrl\('economic-grant'\)"
```

Cada match clasificarlo según la tabla de severidades arriba.
