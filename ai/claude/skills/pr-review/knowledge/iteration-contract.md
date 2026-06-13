# Iteration Contract — reglas para revisar PRs a través de iteraciones

Este documento define cómo el reviewer (`/pr-review` y skills relacionadas) decide **cuándo aprobar**, **cuándo bloquear**, y **cuántas iteraciones acepta** antes de escalar.

Existe para resolver un problema real: sin reglas explícitas, cada iteración del reviewer encuentra nuevos issues (porque revisa con más profundidad o expande superficie). El dev cierra los hallazgos de iter N y recibe un set nuevo en iter N+1. El PR nunca llega a "listo". Esto erosiona confianza y desperdicia tiempo.

**El contrato vincula al reviewer tanto como al dev.**

---

## Regla 1 — Clasificar cada finding por *origen*, no solo por severidad

En iter N≥2, cada finding lleva una de estas etiquetas. Sólo las primeras tres pueden bloquear merge:

| Tag | Definición | ¿Puede bloquear en iter N? |
|-----|------------|-----------------------------|
| **REGRESSION** | Código nuevo introducido entre el SHA de iter N−1 y el SHA de iter N (verificable con `git diff <prev_sha>..<curr_sha>`) que rompe algo. | ✅ Sí, si severidad ≥ bar del trunk |
| **CARRY-OVER** | Finding ya reportado en iter N−1 que no fue cerrado, o fue diferido sin defensa documentada. | ✅ Sí, si su severidad original era bloqueante o si la diferencia se hizo en silencio |
| **PRODUCT_CLARIFICATION** | Ambigüedad de regla externa que se hace visible al revisar el delta de iter N. La regla afecta código tocado en cualquier iter. | ✅ Sí, hasta que producto confirme |
| **DEPTH** | Pre-existente en iter N−1, no detectado, en archivo que el reviewer marcó como auditado. | ❌ **NO bloquea.** Se reporta como CONSIDER + ticket de deuda independiente. |
| **SCOPE_EXPANSION** | Pre-existente en iter N−1, no detectado, en archivo que el reviewer NO había auditado (declarado en su sección "Superficie reviewada"). | ❌ **NO bloquea.** Mismo tratamiento: CONSIDER + ticket. |

### Por qué

"Approve with conditions" en iter N−1 es un contrato implícito: *"si cierras estas N conditions, aprobaré sin más obstrucciones del código actual"*. Si el dev las cierra y el reviewer sube el bar con findings que ya estaban ahí y omitió, es revisionismo — castiga al dev por la sub-cobertura del reviewer.

Calidad/seguridad real no se pierde: los findings DEPTH/SCOPE_EXPANSION se convierten en tickets independientes, con dueño y plazo. Lo que se pierde es la *coerción* de bloquear merge sin causa nueva.

### Cómo verificar el origen

```bash
# REGRESSION check: ¿el archivo se modificó entre iter N-1 y iter N?
gh api "repos/{repo}/compare/{prev_sha}...{curr_sha}" --jq '.files[].filename' | grep -F "{path}"

# Si NO aparece → no es REGRESSION. Es DEPTH o SCOPE_EXPANSION según la sección "Superficie reviewada" de iter N-1.
```

---

## Regla 2 — Severity bar *inmutable* por trunk

Al inicio del trunk (o del primer review), el owner declara el bar. Ejemplos válidos:

- `bar=P0/P1` (solo bugs P0 o P1 bloquean)
- `bar=any-security-MUST-FIX` (cualquier MUST FIX de seguridad bloquea)
- `bar=any-SHOULD-FIX-or-above`
- `bar=critical-only` (solo CRITICAL bloquea)

**Ese bar queda fijo durante toda la vida del trunk y de sus iteraciones.**

El reviewer NO puede subir el bar entre iteraciones. Sólo se puede subir el bar si:

1. El owner lo declara explícitamente en el PR (no inferido).
2. Surge una vulnerabilidad pública nueva que afecta directamente el código del PR.
3. Una regresión en producción reactiva la severidad de un finding diferido.

Bajar el bar (relajar) no requiere justificación; subirlo sí.

### Cómo declarar el bar

En la primera iter, el reviewer extrae el bar del PR body o pregunta al owner. Si no está declarado, asume `bar=MUST-FIX-or-above` (default conservador) y lo dice explícito en el reporte.

```markdown
**Bar de bloqueo del trunk:** P0/P1 (declarado por owner en PR body línea N)
```

---

## Regla 3 — Cada iter declara su *superficie reviewada*

Cada reporte incluye una sección explícita:

```markdown
## Superficie reviewada en esta iter

| Status | Archivos / áreas |
|--------|-------------------|
| ✅ Auditado | <lista de archivos auditados a profundidad> |
| ⚠️ Spot-check | <archivos vistos en pasada superficial> |
| ❌ No auditado | <archivos del PR que no se revisaron> |
```

### Por qué

Convierte la cobertura del reviewer en un dato verificable. Si en iter N−1 dije *"❌ No auditado: migrations RLS"* y en iter N las audito y encuentro N-1, eso es **SCOPE_EXPANSION transparente**, no sorpresa — el dev sabía que ese flanco quedaba abierto y puede cuestionar si bloquea.

Si en iter N−1 dije *"✅ Auditado: migrations RLS"* y en iter N encuentro un finding ahí, **es DEPTH**, lo reconozco como mi error, y va a ticket aparte — no bloquea.

Sin esta sección, cualquier hallazgo nuevo es ambiguo y el reviewer tiene incentivo a expandir silenciosamente.

---

## Regla 4 — Bound de iteraciones: **3 máximo**

| Iter | Quién decide | Qué hace |
|------|--------------|----------|
| **Iter 1** | Reviewer reporta findings + declara bar + declara superficie. | Estado de salida: READY / APPROVE WITH CONDITIONS / BLOCK. |
| **Iter 2** | Reviewer verifica cierre de iter 1 + reporta sólo REGRESSION / CARRY-OVER / PRODUCT_CLARIFICATION. | DEPTH y SCOPE_EXPANSION van a tickets, no bloquean. Estado de salida actualizado. |
| **Iter 3** | Reviewer verifica iter 2. Si quedan bloqueantes legítimos → **escalación a meeting** (tech lead + owner + dev). | Sin meeting, no hay iter 4. |

### Por qué el límite de 3

Un PR que necesita 4+ iters de review es señal de uno o varios de estos problemas, ninguno se resuelve con más iters:

- El PR es demasiado grande y hay que partirlo.
- El alcance/spec no está claro.
- Hay desalineación de criterio entre reviewer y dev.
- El reviewer está expandiendo silenciosamente (violación de Regla 1).

La escalación es la salida sana. El meeting alinea criterio, parte el PR, o desbloquea con decisión de producto/tech lead.

---

## Regla 5 — Estado de salida *explícito* en cada iter

Al final de cada reporte, el reviewer firma uno de estos tres estados. Sin estado, el reporte está incompleto.

### `READY`
Zero bloqueantes según el bar del trunk. PR mergeable. Cualquier finding restante es ticket de deuda independiente (etiquetado con su tag de origen).

```markdown
**Estado de salida:** READY TO MERGE
**Bloqueantes pendientes:** 0
**Tickets de deuda a crear:** <lista con tag de origen>
```

### `APPROVE WITH CONDITIONS`
N bloqueantes específicos y enumerados. Compromiso explícito del reviewer:

> *"Si el dev cierra estas N exactas conditions, la siguiente iter es READY salvo que aparezca REGRESSION / CARRY-OVER no resuelto / PRODUCT_CLARIFICATION nueva. NO se añadirán bloqueantes adicionales por DEPTH ni SCOPE_EXPANSION."*

```markdown
**Estado de salida:** APPROVE WITH CONDITIONS
**Conditions (lista cerrada):**
1. <condition específica + archivo + criterio de verificación>
2. ...
**Compromiso:** si las conditions se cierran, iter N+1 = READY (modulo Regla 1).
```

### `BLOCK`
Problema estructural que requiere replantear. No es revisable con iter normal — va a meeting.

```markdown
**Estado de salida:** BLOCK
**Razón estructural:** <ej. PR demasiado grande, spec ambiguo, mixed pattern P14 detectado, etc.>
**Acción:** meeting con <stakeholders>
```

---

## Cómo aplicar el contract en un reporte

### Iter 1 (primera revisión)

1. Extraer el **bar del trunk** del PR body. Si no está, default `MUST-FIX-or-above` y mencionarlo.
2. Reportar findings normalmente (Pass 1, Pass 2, CCC, etc.).
3. Añadir sección **"Superficie reviewada"** al final.
4. Firmar un **estado de salida** explícito.

### Iter 2+ (revisiones siguientes)

1. **Re-verificar conditions de iter N−1** una por una. Listar cada una con status: cerrada / parcial / no cerrada.
2. **Calcular el delta** de archivos: `gh api "repos/.../compare/{prev_sha}...{curr_sha}" --jq '.files[].filename'`.
3. Para cada finding nuevo en iter N:
   - Si el archivo está en el delta → posible REGRESSION (verificar que el código nuevo causa el bug).
   - Si no está en el delta y estaba en "✅ Auditado" de iter N−1 → DEPTH (ticket, no bloquea).
   - Si no está en el delta y estaba en "❌ No auditado" → SCOPE_EXPANSION (ticket, no bloquea).
   - Si la severidad depende de regla de producto → PRODUCT_CLARIFICATION (bloquea hasta clarificar).
4. Findings CARRY-OVER: re-verificar si se cerraron o difirieron con defensa.
5. Firmar el nuevo estado de salida + sección "Superficie reviewada" actualizada.

### Iter 3 (escalación)

Si quedan bloqueantes legítimos:

```markdown
**Estado de salida:** BLOCK (escalación)
**Razón:** este es el tercer ciclo de review con bloqueantes pendientes. El contrato de iteraciones limita a 3 iters.
**Acción requerida:** meeting con <owner>, <tech lead>, <dev>. Resultados posibles:
- Partir el PR en sub-PRs más pequeños
- Bajar el bar (con decisión documentada)
- Aceptar deuda con tickets dueños
- Re-escribir spec ambiguo
```

---

## Ejemplo de aplicación (PR #414 iter 2)

Contexto: iter 1 reportó 5 SHOULD FIX, iter 2 cerró 4/5, dev difirió 1 sin defensa. Reviewer encontró 4 findings "nuevos" en iter 2.

**Sin contract:** reviewer dice "APPROVE WITH CONDITIONS" con 4 nuevos bloqueantes → dev pelea 3+ iters más → desgaste innecesario.

**Con contract aplicado:**

1. **Verificar origen** de los 4 findings con `gh api .../compare/{iter1_sha}...{iter2_sha}`:
   - N-1 (WITH CHECK gap): archivo `20260520210000_*.sql` NO en el delta → **DEPTH** → ticket, no bloquea.
   - N-2 (cascade self-nomination): archivo `scope-validation.ts` NO en el delta → **DEPTH** → ticket, no bloquea.
   - N-3 (instances.ts sin Zod): archivo NO en el delta → **DEPTH** → ticket, no bloquea.
   - N-4 (Zod ES hardcoded): archivo `AwardForm.tsx` SÍ en el delta (iter 2 añadió i18n wiring), pero el código de los Zod messages ya existía antes → **DEPTH** → ticket, no bloquea.
   - N-5 (distributeRewards atómico): es **CARRY-OVER** de iter 1 #5 sin defensa → bloquea hasta que el dev documente el trade-off o cree ticket.

2. **Estado de salida correcto:** `READY TO MERGE` con 1 caveat (N-5 carry-over que se cierra documentando la decisión, no codeando).

3. **Tickets creados:** 4 (uno por cada DEPTH) con dueño y plazo.

4. **No hay iter 3 necesaria.** El dev cierra el caveat documentando o tickeando, merge sigue.

---

## Anti-patrones del reviewer

Estos comportamientos violan el contract:

- ❌ Subir el bar entre iters sin justificación objetiva.
- ❌ Reportar findings nuevos sin etiqueta de origen.
- ❌ Cambiar la lista de conditions entre iters silenciosamente (añadir o quitar sin reconocer el cambio).
- ❌ No declarar la superficie reviewada (deja al dev sin defensa contra SCOPE_EXPANSION).
- ❌ Permitir iter 4+ sin escalación.
- ❌ Tratar DEPTH como bloqueante porque "ahora que lo veo, no puedo aprobar sin que se arregle". Calidad/seguridad real se preserva via ticket — el bloqueo retroactivo erosiona la confianza sin agregar protección real (el ticket cumple el mismo fin con menos costo).

## Anti-patrones del dev

El contract también pone responsabilidad en el dev:

- ❌ Cerrar conditions superficialmente (commit que dice "fix X" pero no lo cierra realmente).
- ❌ Diferir CARRY-OVER en silencio (sin documentar trade-off ni crear ticket).
- ❌ Mezclar refactor con cierre de conditions (introduce REGRESSION oportunidades).
- ❌ Resistir escalación cuando ya van 3 iters — significa que el problema no es de review, es estructural.
