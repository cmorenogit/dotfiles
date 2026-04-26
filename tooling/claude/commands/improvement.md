---
description: PE Improvement Loop — plan activo, patrones y procesamiento de reportes PE
---

# /improvement — PE Improvement Hub

Sistema de mejora continua basado en reportes PE Anthropic. Este comando es el hub dedicado — los reportes PE NO entran por `/ingest`, entran acá manualmente cuando Ignacio los envía.

## Uso

```bash
/improvement                      # Muestra plan + patrones activos (default)
/improvement review               # Self-assessment de la semana (Y/N por acción)
/improvement history              # Evolución de scores y patrones
/improvement process <contenido>  # Procesa reporte PE nuevo
```

## Contexto

**Engram topic keys:**
- `pe/self/weekly-review-{WXX}` — baseline histórico (1 por semana)
- `pe/self/patterns-current` — todos los patrones activos (accionables + observar + fuera de control)
- `pe/self/improvement-plan-current` — 2-3 acciones SMART de la semana actual

**Doc vault relacionado:** `_work/apprecio/docs/self/improvement-loop.md`

---

## Comportamiento por subcomando

### Default (sin args) — Muestra plan + patrones

Ejecutar:
```
mem_search(query: "pe/self/improvement-plan-current", limit: 1)
mem_get_observation(id: <resultado>)
mem_search(query: "pe/self/patterns-current", limit: 1)
mem_get_observation(id: <resultado>)
```

Mostrar:

```markdown
# 🎯 Plan de Mejora W{XX}

**Baseline:** Score total {N}/100 (Foco X, Velocidad Y, Ownership Z, Coordinación W)
**Meta semana:** {M}/100

## Acciones activas
1. [{categoría}] {acción corta}
   Mecanismo: {cómo se ejecuta}
   Éxito: {evidencia}

2. [{categoría}] {acción corta}
   ...

## Patrones a observar (awareness)
- {patrón} — {fuente}
- {patrón} — {fuente}
- {patrón} — {fuente}

## Referencias
- Baseline: pe/self/weekly-review-{WXX}
- Todos los patrones: pe/self/patterns-current
- Doc vault: _work/apprecio/docs/self/improvement-loop.md
```

### `review` — Self-assessment

Recuperar plan actual. Por cada acción preguntar al usuario:
```
Acción 1 — {descripción}
  ¿Cumplida esta semana? (Y/N/parcial)
  Evidencia/notas: _____
```

Al terminar, guardar en Engram con topic `pe/self/week-closure-{WXX}`:
```
mem_save(
  title: "PE self-assessment W{XX}",
  topic_key: "pe/self/week-closure-{WXX}",
  type: "learning",
  project: "apprecio",
  content: "<assessment estructurado>"
)
```

### `history` — Evolución

Ejecutar:
```
mem_search(query: "pe/self/weekly-review", limit: 10)
```

Para cada review, extraer: semana, score total, 4 scores dimensionales. Mostrar tabla:

| Semana | Total | Foco | Velocidad | Ownership | Coordinación |
|--------|-------|------|-----------|-----------|--------------|
| W16    | 72    | 60   | 78        | 80        | 70           |
| W17    | ?     | ?    | ?         | ?         | ?            |

Más: lista de patrones que cambiaron de estado entre reviews.

### `process <contenido>` — Procesar reporte PE nuevo

El usuario pega el contenido del reporte o pasa un path a archivo local.

**Flujo:**

1. **Parsear** el reporte buscando:
   - Semana reportada (ej: "14-20 abril 2026" → W16)
   - Scoring por dimensión (Foco, Velocidad, Ownership, Coordinación, Total)
   - Patrones detectados (con estado: mejorando/estable/empeorando)
   - Logros, desviaciones, pendientes decisionales

2. **Guardar baseline:**
   ```
   mem_save(
     title: "Weekly PE Review W{XX} — {fechas}",
     topic_key: "pe/self/weekly-review-{WXX}",
     type: "learning",
     project: "apprecio",
     content: <reporte estructurado>
   )
   ```

3. **Comparar con review anterior:**
   ```
   mem_search("pe/self/weekly-review", limit: 2)
   ```
   - Calcular delta por dimensión
   - Identificar patrones nuevos / resueltos / persistentes
   - Detectar refutaciones del usuario (si las hay)

4. **Proponer update de `patterns-current`:**
   Mostrar al usuario:
   ```
   🔄 Cambios detectados en patterns-current:
     + NUEVO: "{patrón emergente}"
     - RESUELTO: "{patrón anterior que ya no aparece}"
     ⚠️ EMPEORANDO: "{patrón que el reporte marca peor}"
     ✅ MEJORANDO: "{patrón que el reporte marca mejor}"

   ¿Actualizar patterns-current con estos cambios? (Y/N/editar)
   ```

5. **Proponer nuevo `improvement-plan-current`:**
   Basado en las 2 dimensiones más bajas del nuevo scoring + patrones accionables empeorando:
   ```
   🎯 Plan sugerido para W{XX+1}:

   Acción 1 — {dimensión más baja o patrón crítico}
     Meta: {número concreto}
     Mecanismo: {propuesta}
     Éxito: {evidencia verificable}

   Acción 2 — ...

   ¿Aprobar este plan? (Y/N/editar)
   ```

   Solo al confirmar, hacer `mem_save` del nuevo plan.

6. **Reportar delta:**
   ```
   ✅ Reporte W{XX} procesado.
   
   Scoring: {delta vs anterior}
   Patrones: {N actualizados}
   Plan nuevo: {activo desde hoy}
   
   Próximo check: /improvement review (al final de la semana)
   ```

---

## Reglas

- **NO auto-ejecutar updates de Engram** sin confirmación del usuario (excepto el baseline del reporte nuevo, que siempre se guarda).
- **NO tocar `/ingest`** — los reportes PE no son reuniones, son un canal separado.
- **Máximo 2-3 acciones por plan** — evitar sobrecarga.
- **Referencias siempre a topic keys de Engram** para que otros skills/conversaciones puedan recuperar.
- **Idioma:** español en output al usuario, inglés en topic keys y estructuras.
- **Refutaciones del usuario se guardan textuales** dentro del baseline — útil para corregir el agente PE en futuras interacciones.


---

## 📎 Familia PE Daily Workflow
  /today · /pulse · /equipo · /ingest · /patrol · /improvement
  Referencia completa: /pe
