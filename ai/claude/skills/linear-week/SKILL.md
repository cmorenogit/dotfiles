---
name: linear-week
description: >
  Harvester semanal del sistema linear-*: barre la actividad de la semana en los teams (errores y
  devoluciones DE TODO EL EQUIPO, no solo menciones a César), lee la transcripción del weekly en Drive,
  destila lecciones vía /linear-learn (dedup), consume la telemetría para calibrar gauge/gate, y hace
  rollup al estado semanal del vault. Cierra el loop de aprendizaje a escala semana. NUNCA postea.
  Triggers: "/linear-week", "retrospectiva de la semana", "qué aprendimos esta semana", "cierre de semana linear".
---

# Linear Week — harvester semanal (cierra el loop de aprendizaje)

Contrato: `~/.claude/skills/_shared/linear-contract.md` (B1 scan, B4 learn, B5 telemetría, B3 memoria).
Cadencia: 1 vez por semana — ideal **después del weekly del martes** o al cierre del viernes.
(Re-corridas son idempotentes —dedup por `topic_key` + rollup con diff confirmado— pero correrlo >1x/semana es pagar el barrido completo para una cosecha vacía: la señal intra-semana la da `today`; lo urgente puntual, `learn`.)

## 1 · Barrido de la semana (equipo completo, no solo menciones)
Con `list_issues(updatedAt="-P7D")` por team (campos lean) + `list_comments` de los issues con señal, buscá **señales de error/corrección del EQUIPO**:
- Issues devueltos de QA o reabiertos · PRs con CHANGES REQUESTED o iteraciones ≥2
- Correcciones/llamadas de atención de Ignacio (a cualquiera) · decisiones de proceso en hilos
- Estados desincronizados que alguien tuvo que corregir
Delegá el barrido a un sub-agente (threads paginados, cite-or-discard del triaje). Salida: lista de eventos con quote+ref.

## 2 · Fuente meetings (las decisiones que Linear no ve)
Buscá en Drive la transcripción del weekly de la semana (`gws drive files list` — carpeta Meet Recordings / "Notas de Gemini", `modifiedTime` de la semana). Si existe, extraé (sub-agente): reglas de proceso fijadas, decisiones que cierran/cambian hilos de Linear, tareas asignadas a César. **Cruzá contra los hilos abiertos**: si una decisión de meeting cierra o vuelve stale algo en la cola → marcarlo (anti-stale, caso RYR-75/weekly 09-06).

## 3 · Destilar → learn (con dedup)
Cada candidato de lección pasa por el pipeline de **`/linear-learn`** (destilar durable + `applies_to` + `last_confirmed` + dedup + rutear). Categorías:
- Lección de proceso/review → `review/lessons/` (canónico `linear-review-lessons.md`)
- Criterio de Ignacio → `review/ignacio/criteria` (merge)
- **Patrón del equipo** (error recurrente de CUALQUIER miembro) → `review/team-patterns/{slug}` + sección "Team patterns" en `linear-review-lessons.md`. El gate/respond los cita como contexto ("este PR repite el patrón X"), nunca como reproche personal.
Regla anti-bloat: **máx 3-5 lecciones por semana** — solo lo recurrente o de alto costo. Una semana sin lecciones nuevas es un resultado válido.
**Curaduría (promoción, no acumulación):** del weekly/meetings solo se promueve lo que pasa el test *"¿cambia cómo reviso/respondo el mes que viene?"*. Lo coyuntural (asignaciones, fechas, números de la semana) va SOLO al rollup del estado semanal. Además: revisar entradas existentes con `last_confirmed` > 90 días → re-confirmar, fusionar o retirar (proponer a César).

## 4 · Consumir telemetría (calibración)
Leé los bloques `## Telemetría` de las colas `today-*.md` de la semana:
- borradores `rehechos` > `usados` → el drafting está fallando → ¿qué editó César? → lección de estilo/criterio
- `gate fail_falso` alto → el gate exagera → revisar el criterio que más falla
- gauge: ¿algún trivial resultó sustancial (o viceversa)? → ajustar señales del GAUGE en el contrato
Proponé los ajustes; César confirma antes de tocar el contrato.

## 5 · Rollup al estado semanal
Consolidá en `~/Code/_vault/_work/apprecio/weekly/{YYYY-Www}/estado.md` (crear si no existe, formato de las semanas previas): qué respondiste/cerraste, pendientes que arrastran, lecciones de la semana (links), ajustes de calibración. **Mostrar diff → César confirma** antes de escribir.

## Output
Resumen corto: eventos de la semana → lecciones destiladas (con destino) → decisiones de meetings que afectan hilos → calibración propuesta → rollup. Sin relleno; lo accionable arriba.
