---
description: Daily briefing PE — estado-semana + Linear + self-assessment + rutas de accion
---

# /today — Briefing PE Diario

Genera un briefing diario orquestado con subagentes. Cruza estado-semana.md (documento operativo) con Linear (estado real de issues) para producir un análisis PE con self-assessment, alertas y rutas de acción.

**Uso:**
```bash
/today              # Briefing estándar
/today --full       # Detalle expandido por item
```

## Contexto

**Rol:** César Moreno — Principal Engineer, Apprecio (desde Abril 2026).
**Scope:** R&R, Fuerza, Smart Loyalty, Engagement, Incentivos.

**Vault:** `docs-projects` — path: `/Users/cmoreno/Code/docs-projects`
**Estado-semana:** `_work/apprecio/estado-semana.md` (relativo al vault)
**Git root:** `/Users/cmoreno/Code/docs-projects/`

**Equipos Linear:**
| Team | ID |
|------|------|
| RYR | `ddeaea1c-b29b-45b4-82b2-6cd261c47aa5` |
| Platform | `d8d7e52e-13bb-4c56-b1fb-8b496063ab13` |
| App | `dbcc43e5-a2e1-4060-8759-591a857fbc2c` |
| Product Planning | `280b014b-1731-4bd9-996a-8b2e7d8370db` |

**César Linear User ID:** `6a1e659a-ca3d-417f-b460-b62307d9354d`

**Miembros del equipo:**
| Nombre | ID | Rol |
|--------|------|-----|
| Cesar | `6a1e659a-ca3d-417f-b460-b62307d9354d` | PE (tú) |
| Samuel | `3e1e34b6-b368-44fb-9905-8ba595058ae4` | Dev R&R |
| Faber | `a610cc2e-6123-4711-b6ba-d2f038dce5a6` | Dev R&R + App |
| Kevin | `1d2fb141-6dc1-4d81-babd-33a274528009` | Dev App |
| Nicole | `74892295-d834-4351-b7f2-a39633bf01d3` | Product/Design |
| Julieth | `d59d2ef5-330f-40bd-8314-7a99da2c7e35` | QA |
| Ignacio | `1f03f08d-db10-4bf2-8999-499b7842f50c` | Head of Product |

## Flujo de Ejecucion

### FASE 0: Detectar cambio de semana

Obtener la hora y fecha actual del sistema:
```bash
date "+%Y-W%V %A %Y-%m-%d %H:%M"
```

Leer frontmatter de estado-semana.md → campo `week`.

**Si semana ISO actual ≠ semana del frontmatter:**

```
⚠️ Nueva semana detectada (W{actual}). Estado-semana es de W{anterior}.

Voy a:
1. Archivar W{anterior} → weekly/{anterior}/estado.md
2. Carry forward items activos a W{actual}
3. Limpiar completados y notas de reunión

Aprendizajes PE de W{anterior}:
  1. "Insight 1"
  2. "Insight 2"
¿Cuáles guardar en Engram antes de archivar? [1,2 / todos / ninguno]
```

**Ejecutar transición:**

1. **Archivar:** Copiar estado-semana.md → `weekly/YYYY-W{anterior}/estado.md`
   Agregar al final del archivo archivado:
   ```markdown
   ---
   ## Cierre W{anterior}
   - Items que entraron: N
   - Items completados: N
   - Items que pasan a W{actual}: N (carry forward)
   - Bloqueados persistentes: [lista]
   ```

2. **Guardar en Engram** los aprendizajes PE confirmados por el usuario.
   Topic key: `pe/learning/{slug-descriptivo}`
   **NUNCA guardar automáticamente.** Solo los confirmados.

3. **Limpiar estado-semana.md:**

   | Sección | Acción |
   |---------|--------|
   | Frontmatter | Actualizar `week`, `updated`, reset contadores, nuevo `sprint_goal: "TBD"` |
   | Tickets FSV | CARRY FORWARD (los activos) |
   | Tareas en Progreso | CARRY FORWARD (las activas) |
   | Desarrollos en Progreso | CARRY FORWARD (los activos) |
   | Estado del Equipo | CARRY FORWARD (mantener personas, reset "Comprometió" a vacío) |
   | Aprendizajes PE | LIMPIAR (ya archivados + Engram) |
   | Completados | LIMPIAR (ya en archivo) |
   | Notas de reuniones | LIMPIAR (ya en weekly/) |
   | Resumen Rápido | REGENERAR con items carry forward |
   | Tareas de StOn | **NO TOCAR** (sección manual de César) |

4. **Git commit:**
   ```bash
   cd /Users/cmoreno/Code/docs-projects
   git add "_work/apprecio/"
   git commit -m "docs: archive W{anterior}, start W{actual}"
   git push
   ```

5. Continuar con el briefing normal de la nueva semana.

### FASE 1: Recopilacion paralela (3 subagentes)

Lanza TRES subagentes en paralelo:

**Subagente 1 — ESTADO LOCAL:**

Lee estado-semana.md completo. Preferir `obsidian` CLI, con fallback a Read directo:
```bash
obsidian file vault=docs-projects path="_work/apprecio/estado-semana.md" 2>/dev/null
```

Extrae y estructura:
- **Mis items activos:** Tickets FSV + Tareas + Desarrollos (con estado y prioridad)
- **Items bloqueados:** Cuáles y por qué
- **Items completados esta semana:** Conteo y lista
- **Sprint goal:** Del frontmatter
- **Equipo (resumen):** 1 línea por persona desde sección "Estado del Equipo"
- **Aprendizajes PE activos:** Sección "Aprendizajes PE Semana"
- **Día de la semana y semana ISO**
- **Última actualización** (campo `updated` del frontmatter — ¿cuán fresco es el doc?)

**Subagente 2 — LINEAR:**

Consultar Linear MCP. Ejecutar en paralelo:

A. **Mis issues activos:**
```
list_issues(assignee: "6a1e659a-ca3d-417f-b460-b62307d9354d", state: "started", limit: 20)
list_issues(assignee: "6a1e659a-ca3d-417f-b460-b62307d9354d", state: "unstarted", limit: 20)
```

B. **Issues actualizados recientemente (últimas 24h, todos los teams):**
```
list_issues(updatedAt: "-P1D", limit: 30, orderBy: "updatedAt")
```

C. **Issues del equipo — resumen light (1 query por persona, solo started):**
Para cada miembro: `list_issues(assignee: "{id}", state: "started", limit: 10)`

Analizar y producir:
1. **Mis issues con estado real** — identifier, título, estado, prioridad, último update
2. **Issues sin actividad >3 días** — flag para alerta
3. **Issues donde el estado cambió recientemente** — transiciones importantes
4. **Recordatorios:** Issues que deberían cambiar de estado basándose en lo que dice estado-semana vs lo que dice Linear:
   - "Estado-semana dice QA pero Linear dice In Progress → ¿actualizar Linear?"
   - "Estado-semana dice Completado pero Linear no está Done → ¿cerrar en Linear?"
5. **Equipo light:** 1 línea por persona (N issues activos, último movimiento)

**Subagente 3 — CONTEXTO + CIERRE ANTERIOR:**

Consultar Engram para contexto de largo plazo:
```
mem_search(query: "pe learning decisions conventions", limit: 5)
```

**Recuperar último cierre de sesión (Dynamic Context Injection):**
```
mem_search(query: "pulse/close", limit: 1)
```
Si hay un pulse/close de las últimas 24h, extraer:
- Pendientes que quedaron para hoy
- Menciones sin respuesta al cierre
- Issues stale reportados
- Resumen del día anterior

Leer daily note de Obsidian (si existe):
```bash
obsidian daily vault=docs-projects 2>/dev/null
```

Producir:
- **Cierre anterior:** pendientes, menciones sin respuesta, resumen (si hay pulse/close reciente)
- Decisiones PE recientes relevantes para hoy
- Contexto de aprendizajes persistentes
- Daily note existente (si hay)

### FASE 2: Analisis PE (subagente ANALISTA)

Recibe los 3 outputs. Genera el briefing completo.

#### Template de Output

```markdown
# Hoy — {Día} DD Mes YYYY (W{XX})
Sprint: {sprint_goal}

## 📌 Desde tu último cierre
(Solo si hay pulse/close reciente en Engram. Si no hay, omitir esta sección.)
  Pendientes de ayer: {lista de issues + acción pendiente}
  Sin respuesta al cierre: {menciones que quedaron sin contestar}
  Resumen día anterior: {1 línea del resumen}

## 🔴 Sin Respuesta (necesitan tu acción)

Menciones directas a @cesar/@cmoreno en Linear donde NO has respondido:
  - {ISSUE-ID}: {Autor} ({hace Xh/días}) — {resumen 1 línea}
  - {ISSUE-ID}: {Autor} ({hace Xh/días}) — {resumen 1 línea}
(Si no hay menciones sin respuesta, mostrar: "✅ Todas las menciones respondidas")

## ⚡ Foco del Día

1. **[PROYECTO] Acción concreta** — qué hacer exactamente hoy
2. **[PROYECTO] Segunda prioridad** — acción concreta
3. **[PROYECTO] Tercera si aplica** — acción concreta

## 📋 Mis Tareas (estado-semana × Linear)

| Item | Estado Semana | Estado Linear | Divergencia? |
|------|---------------|---------------|-------------|
| [R&R] Scorecards | 🟡 QA 2da revisión | RYR-XX In Review | ✅ Alineado |
| [R&R] Reg. Fotográfico | 🟡 Quiz en curso | RYR-XX Todo | ✅ Alineado |
| [ENG] Desafíos | 🔴 Bloqueado Core | PLA-XX Blocked | ✅ Alineado |
| [ENG] Producción | 🟡 PR listo | — (no en Linear) | ⚠️ Sin tracking |

## ⚠️ Alertas

🔔 DIVERGENCIAS:
  - [PROYECTO] Item: estado-semana dice X pero Linear dice Y → acción sugerida

🕐 SIN ACTIVIDAD (>3 días):
  - RYR-XX "Título" — último update hace N días

📌 RECORDATORIOS:
  - "Actualiza RYR-XX a Done en Linear (estado-semana dice completado)"
  - "Scorecards depende de revisión de Ignacio — sin actividad hace N días"

## 👥 Equipo (resumen)

| Persona | Issues activos | Último mov. | Nota |
|---------|---------------|-------------|------|
| Samuel | N | hace Xh | [issue principal] |
| Faber | N | hace Xh | [issue principal] |
| Kevin | N | hace Xh | [issue principal] |
| Julieth | N QA queue | hace Xh | |

(Para más detalle → /equipo)

## 📊 Self-Assessment PE

- **Progreso semana:** N de M items completados ({%})
- **Pacing:** {en track / atrasado / adelantado} — quedan N días hábiles
- **Riesgo principal:** {descripción + por qué + sugerencia}
- **Items stale (arrastre):** N items sin movimiento >1 semana
- **Bloqueados persistentes:** N — {acción sugerida}

## 🎯 Rutas de Acción

Para cada alerta o riesgo, una acción concreta:
- → "Escribir a Ignacio por Chat pidiendo 2da revisión Scorecards"
- → "Cambiar RYR-XX a In Review en Linear"
- → "Contactar Fabricio por Desafíos — lleva N semanas bloqueado"
```

#### Criterios para "Foco del Día"

Priorizar en este orden:
1. Lo que se desbloqueó recientemente (máximo impacto, acción inmediata)
2. Lo marcado como ⚡ FOCO en estado-semana
3. Deadlines esta semana
4. Lo que más progreso puede tener hoy (in_progress con menor bloqueo)
5. Tickets FSV con prioridad alta

Máximo 3 items. Cada uno con acción CONCRETA.
- ✅ "Implementar cálculo de progreso en challenges-service"
- ❌ "Avanzar con desafíos"

#### Variaciones por Día

Las variaciones son ADICIONES al template base:

| Día | Adición |
|-----|---------|
| **Lunes** | Si existe `weekly/WXX/planning.md`, agregar `## 🎯 Objetivos Semana` con 3-4 bullets ANTES de Foco |
| **Jueves** | Agregar `## 📝 Preparar Checkin` con: qué completé, qué sigue, bloqueados para reportar |
| **Viernes** | Agregar `## 📦 Cierre Semana` con: pendientes para lunes, items a arrastrar, sugerir ejecutar /equipo para revisión semanal |

#### Modo --full

En modo `--full`, expandir cada item de "Mis Tareas" con:
- Descripción breve
- Último avance registrado en estado-semana
- Comentarios recientes de Linear (si hay)
- Dependencias
- Contexto de Engram (si hay)

### FASE 3: Sync a Google Drive (silencioso)

Después de mostrar el briefing, sincronizar estado-semana.md a Drive.

**Carpeta destino:** `Personal Cesar/Estado Semanal/` (ID: `11R8Pa7w_oquA_1MeiO7ZLHIXiti_Fb-Z`)

```bash
# Buscar si existe
gws drive files list --params '{"q": "name=\"estado-semana.md\" and \"11R8Pa7w_oquA_1MeiO7ZLHIXiti_Fb-Z\" in parents and trashed=false", "fields": "files(id,name)"}'

# Si existe → actualizar
gws drive files update --params '{"fileId": "ID_ARCHIVO"}' --upload /Users/cmoreno/Code/docs-projects/_work/apprecio/estado-semana.md

# Si no existe → crear
gws drive files create --json '{"name": "estado-semana.md", "parents": ["11R8Pa7w_oquA_1MeiO7ZLHIXiti_Fb-Z"]}' --upload /Users/cmoreno/Code/docs-projects/_work/apprecio/estado-semana.md
```

No reportar al usuario salvo error: `⚠️ Sync a Drive falló: [error]`

## Reglas Generales

- **NO modificar estado-semana.md** (excepto transición de semana). /today es READ-ONLY para el briefing.
- **NO modificar Linear.** Solo leer. Las alertas sugieren acciones pero no las ejecutan.
- **NO guardar en Engram automáticamente.** Solo durante transición de semana, con confirmación.
- **Máximo ~40 líneas** en modo normal. ~80 en `--full`.
- **Foco en acción:** Cada item dice QUÉ HACER, no solo estado.
- **Sin juicios sobre personas** — datos, no opiniones.
- **Hora local:** America/Santiago (Chile). Usar `date` del sistema para hora actual. Convertir timestamps UTC de Linear a hora local.
- **Si Linear MCP falla:** Degradar a solo estado-semana con warning: `⚠️ Linear no disponible — briefing basado solo en estado-semana.`
- **Si Obsidian CLI falla:** Fallback a Read directo de `/Users/cmoreno/Code/docs-projects/_work/apprecio/estado-semana.md`
- **Priorizar brevedad.** Es un briefing, no un reporte. Si quiero más detalle del equipo → `/equipo`.
- **Siempre terminar el briefing con el bloque de workflow:**

```
## 💡 Tu workflow del día
  /pulse         → check rápido cada 1-2h (menciones, pendientes)
  /equipo        → contexto del equipo si necesitas
  /ingest        → después de reuniones
  /patrol        → monitoreo automático (con /loop)
  /pulse --close → cierre de sesión (guarda contexto para mañana)
  /improvement   → plan activo de mejora PE (si hay reporte reciente)
```

---

## Integración con Improvement Loop (awareness ligera)

Antes de cerrar el briefing, agregar una sección compacta con el plan activo de mejora (si existe):

1. Ejecutar `mem_search(query: "pe/self/improvement-plan-current", limit: 1)`
2. Si hay resultado → recuperar observación y extraer las 2-3 acciones
3. Mostrar bloque compacto (máximo 3 líneas):

```
📎 Mejora activa W{XX}: {acción 1 resumida} · {acción 2 resumida}
   Detalle completo: /improvement
```

Si no hay plan activo en Engram, omitir esta sección silenciosamente. No inventar acciones.

**Awareness orgánica adicional (no forzada):**
- Si durante el análisis detectás que algún patrón de `pe/self/patterns-current` se cruza con el contexto del día, mencionarlo brevemente en "Alertas" — no forzar, solo cuando el contexto lo amerita genuinamente.

### Subagente LINEAR — Mejora: Detección de "Sin Respuesta"

El subagente LINEAR DEBE incluir esta lógica adicional:

Para CADA issue activo de César, obtener últimos 3 comentarios. Si el último comentario:
- NO es de César (author.id ≠ "6a1e659a-ca3d-417f-b460-b62307d9354d")
- Y menciona @cesar, @cmoreno, o es un reply directo a César

→ Marcar como 🔴 SIN RESPUESTA con: issue ID, autor, fecha, resumen.

Priorizar menciones de Ignacio (ID: 1f03f08d-db10-4bf2-8999-499b7842f50c) — siempre van primero.


---

## 📎 Familia PE Daily Workflow
  /today · /pulse · /equipo · /ingest · /patrol · /improvement
  Referencia completa: /pe
