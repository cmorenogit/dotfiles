---
description: Radar del equipo — Linear + estado-semana cruzado, delivery health, blockers, deep dive por persona
---

# /equipo — Radar PE del Equipo

Análisis profundo del estado del equipo cruzando Linear (estado real) con estado-semana (compromisos de reunión). Orientado al rol de Principal Engineer: detectar dependencias, cuellos de botella y oportunidades de intervención.

**Uso:**
```bash
/equipo                # Estado completo del equipo
/equipo samuel         # Deep dive en una persona específica
/equipo --blockers     # Solo issues bloqueados y dependencias
```

## Contexto

**Rol:** César Moreno — Principal Engineer, Apprecio.
**Objetivo PE:** Visibilidad macro para detectar patrones, cuellos de botella y oportunidades de intervención. NO es jefe — es referente técnico que necesita contexto para desbloquear y dar seguimiento.

**Vault:** `docs-projects` — path: `/Users/cmoreno/Code/docs-projects`
**Estado-semana:** `_work/apprecio/estado-semana.md` (sección "Estado del Equipo")

**Equipos Linear:**
| Team | ID | Miembros principales |
|------|------|-----|
| RYR | `ddeaea1c-b29b-45b4-82b2-6cd261c47aa5` | César, Samuel, Faber |
| Platform | `d8d7e52e-13bb-4c56-b1fb-8b496063ab13` | César (Engagement) |
| App | `dbcc43e5-a2e1-4060-8759-591a857fbc2c` | Kevin, Faber |
| Product Planning | `280b014b-1731-4bd9-996a-8b2e7d8370db` | Nicole |

**Miembros del equipo:**
| Nombre | ID | Foco |
|--------|------|------|
| Samuel | `3e1e34b6-b368-44fb-9905-8ba595058ae4` | Dev R&R |
| Faber | `a610cc2e-6123-4711-b6ba-d2f038dce5a6` | Dev R&R + App |
| Kevin | `1d2fb141-6dc1-4d81-babd-33a274528009` | Dev App |
| Nicole | `74892295-d834-4351-b7f2-a39633bf01d3` | Product/Design |
| Julieth | `d59d2ef5-330f-40bd-8314-7a99da2c7e35` | QA |
| Ignacio | `1f03f08d-db10-4bf2-8999-499b7842f50c` | Head of Product |

## Flujo de Ejecucion

### Modo: Estado completo (default)

#### FASE 1: Recopilacion paralela (3 subagentes)

**Subagente 1 — LINEAR POR PERSONA:**

Para CADA miembro del equipo (excepto Linear bot):
```
list_issues(assignee: "{user_id}", state: "started", limit: 30)
list_issues(assignee: "{user_id}", state: "unstarted", limit: 30)
```

Para cada persona, calcular:
| Métrica | Cómo |
|---------|------|
| **Workload** | Conteo de issues activos (started + unstarted asignados) |
| **Último movimiento** | Issue con `updatedAt` más reciente |
| **Stale** | Issues sin update en >3 días |
| **En Review/QA** | Issues en estados de revisión |

**Subagente 2 — BLOCKERS Y DEPENDENCIAS:**

```
list_issues(state: "blocked", limit: 50)
```

Para cada issue bloqueado:
- ¿Quién es el assignee?
- ¿Desde cuándo está bloqueado? (tiempo en estado)
- ¿Hay dependencias explícitas? (issues que bloquean)
- ¿Quién puede desbloquearlo?

También buscar issues sin asignar (potenciales huérfanos):
```
list_issues(assignee: "null", state: "unstarted", limit: 20)
```

**Subagente 3 — ESTADO-SEMANA (EQUIPO):**

Leer sección "Estado del Equipo" de estado-semana.md:
```bash
obsidian file vault=docs-projects path="_work/apprecio/estado-semana.md" 2>/dev/null
```
Fallback: `Read /Users/cmoreno/Code/docs-projects/_work/apprecio/estado-semana.md`

Extraer para cada persona:
- **Trabajando** (según reunión)
- **Comprometió** (qué dijo que haría)
- **Bloqueos reportados** (en reunión)
- **Último update conocido**

También leer "Aprendizajes PE Semana" para contexto de patrones detectados.

#### FASE 2: Analisis PE Equipo (subagente ANALISTA)

Recibe los 3 outputs. Cruza Linear (realidad) con estado-semana (compromisos).

**Template de Output:**

```markdown
📊 EQUIPO — DD Abr YYYY, HH:MM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👤 SAMUEL — N issues activos
  🟡 RYR-XX Titulo — [estado Linear]
     Último update: hace Xh | En este estado: X días
  🟡 RYR-XX Titulo — [estado Linear]
     Último update: hace Xh
  📋 Comprometió (reunión): "descripción del compromiso"
  🔍 Divergencia: [si hay diferencia entre compromiso y realidad Linear]
  ⚠️ Stale: RYR-XX sin movimiento desde DD Mes
  Completados esta semana: X

👤 FABER — N issues activos
  [misma estructura]

👤 KEVIN — N issues activos
  [misma estructura]

👤 NICOLE — N issues activos
  [misma estructura]

👤 JULIETH (QA) — N issues activos
  [misma estructura, foco en QA queue]

👤 IGNACIO — N issues activos
  [misma estructura, foco en reviews pendientes]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 BLOQUEADOS
  PLA-XX Desafíos — bloqueado hace X días (Core/Fabricio)
  Quién desbloquea: Fabricio | Acción PE: escalar a Ignacio
  [otros bloqueados]

⚠️ ALERTAS PE (Delivery Health)
  📐 Definition: X issues sin descripción adecuada
  📊 Execution: X issues stale (>3 días sin movimiento)
  👤 Ownership: Samuel tiene X issues, Faber tiene Y — ¿desbalance?
  🔄 Divergencias: X compromisos de reunión no alineados con Linear
  🔮 Predictability: X items arrastrados de semanas anteriores

📈 RESUMEN
  | Persona  | Activos | Review | Completados | Stale | Divergencias |
  |----------|---------|--------|-------------|-------|-------------|
  | Samuel   |    X    |   Y    |      Z      |   W   |      N      |
  | Faber    |    X    |   Y    |      Z      |   W   |      N      |
  | Kevin    |    X    |   Y    |      Z      |   W   |      N      |
  | Julieth  |    X    |   Y    |      Z      |   W   |      N      |
  | Total    |    X    |   Y    |      Z      |   W   |      N      |

🏗️ SIN ASIGNAR (huérfanos)
  RYR-XX "Título" — creado hace Xd, sin asignar
  [otros]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Modo: Persona específica (`/equipo samuel`)

Si se pasa un nombre como argumento:

1. Identificar el user por nombre (case-insensitive)
2. Consultar TODOS sus issues (activos, completados recientes, bloqueados)
3. Para cada issue, obtener comentarios recientes (`list_comments`)
4. Leer estado-semana sección de esa persona
5. Generar vista detallada:

```markdown
📊 EQUIPO — Samuel
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 COMPROMISOS (reunión) vs REALIDAD (Linear)
  Comprometió: "Entrenamientos en QA hoy" (planning 6 Abr)
  Realidad: RYR-XX Entrenamientos — [estado actual] (último update: Xh)
  Alineación: ✅ / ⚠️ / 🔴

📋 ISSUES ACTIVOS (N)
  🟡 RYR-XX Entrenamientos
     Estado: [estado] | Prioridad: [prioridad]
     Descripción: [primeras 2 líneas]
     Último comentario: "[texto]" — Autor, hace Xh
     Tiempo en estado actual: X días

  🟡 RYR-XX Tipos de Reconocimiento
     [similar]

✅ COMPLETADOS RECIENTES (últimos 14 días)
  ✅ RYR-XX [título] — cerrado DD Mes

📊 MÉTRICAS
  Issues cerrados (30 días): X
  Issues stale (>3d): X
  Ratio completados/abiertos: X/Y

🔬 SEÑALES PE
  [Observaciones relevantes: stale, sobrecarga, bloqueos, dependencias]
  [Sugerencias de acción: sync, revisión, desbloqueo]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Modo: Solo bloqueados (`/equipo --blockers`)

1. Consultar issues bloqueados en todos los teams
2. Para cada bloqueado, buscar dependencias y comentarios
3. Cruzar con estado-semana (¿se mencionó el bloqueo en reunión?)
4. Mostrar cadena de bloqueo y quién puede desbloquear

```markdown
🔴 BLOQUEADOS — DD Abr YYYY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PLA-XX Desafíos + Registro de Avance
  Assignee: César | Bloqueado: X días
  Razón: Esperando respuesta Core/Fabricio
  Mencionado en reunión: ✅ (planning 6 Abr)
  Acción PE: Escalar a Ignacio si no hay respuesta en 48h
  Cadena: Desafíos → Cálculo Progreso → Puntos (Fabricio)

[otros bloqueados con misma estructura]

📊 RESUMEN BLOCKERS
  Total: N bloqueados
  Bloqueados por Core: N
  Bloqueados por Ignacio (reviews): N
  Bloqueados técnicos: N
  Persistentes (>1 semana): N
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Delivery Health — 5 Dimensiones

Para el modo completo, evaluar estas señales:

| Dimensión | Señal | Detección |
|-----------|-------|-----------|
| **Definition** | Issue sin descripción | Description vacío o < 50 chars |
| **Definition** | Issue sin criterios de aceptación | No tiene checklist ni acceptance criteria |
| **Execution** | Issue >7 días sin movimiento | updatedAt > 7 días |
| **Execution** | Issue bloqueado >3 días | Blocked state + updatedAt > 3d |
| **Ownership** | Dev con >5 issues activos | Count > 5 per person (sobrecarga) |
| **Ownership** | Dev con 0 issues activos | Count = 0 per person (capacidad ociosa) |
| **Ownership** | Review pendiente >2 días | "In Review" + updatedAt > 2d (cuello de botella) |
| **Predictability** | Divergencia reunión-Linear | Compromiso en estado-semana ≠ estado en Linear |
| **Predictability** | Items arrastrados >2 semanas | Issue sin cambio de estado en >14 días |

## Reglas Generales

- **NO modificar Linear** — este comando es read-only. Nunca crear, actualizar o cerrar issues.
- **NO modificar estado-semana** — solo leer la sección equipo.
- **NO guardar en Engram** — /equipo es consulta, no persistencia.
- **Sin juicios de valor sobre personas** — reportar datos, no opiniones. "3 días sin movimiento" sí. "Samuel es lento" no.
- **Actionable** — cada alerta sugiere qué hacer: "sync con Samuel", "revisar PR", "escalar a Ignacio".
- **Divergencias son oportunidades** — no son errores. "Samuel dijo X pero Linear dice Y" puede significar que no actualizó Linear, no que incumplió.
- **Hora local:** America/Santiago (Chile). Usar `date` del sistema. Convertir UTC de Linear a hora local.
- **Si Linear MCP falla:** Degradar a solo estado-semana sección equipo, con warning.
- **Si Obsidian CLI falla:** Fallback a Read directo del path absoluto.
