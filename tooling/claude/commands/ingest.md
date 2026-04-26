---
description: Procesa transcripcion de reunion → actualiza estado-semana + weekly summary + sugiere aprendizajes PE
---

# /ingest — Procesador de Reuniones

Procesa transcripciones de reuniones, actualiza estado-semana.md como documento vivo, genera resumen semanal, y sugiere aprendizajes PE para confirmacion del usuario.

**Input:** `$ARGUMENTS` (archivo local, keyword para buscar en Drive, o vacío para la más reciente)

## Contexto

**Rol:** César Moreno — Principal Engineer, Apprecio.
**Vault:** `docs-projects` — path: `/Users/cmoreno/Code/docs-projects`
**Workspace:** `_work/apprecio/` (relativo al vault)
**Git root:** `/Users/cmoreno/Code/docs-projects/`

**Estructura del workspace:**
```
_work/apprecio/
├── estado-semana.md          ← documento vivo (se actualiza por merge)
├── transcripts/              ← transcripciones raw
├── weekly/YYYY-WXX/          ← resumenes organizados por semana
│   ├── planning.md
│   ├── checkin.md
│   └── adhoc/
├── .processed.json           ← tracking de transcripciones procesadas
└── config/
    ├── context.md            ← ritmo semanal, horario
    └── sources.json          ← proyectos vinculados
```

## Flujo de Ejecucion

### FASE 0: Obtener transcripcion

Determinar qué procesar segun `$ARGUMENTS`:

**Caso 1: Sin argumentos** → Buscar la transcripcion mas reciente en Google Drive
```bash
# Buscar en la carpeta de grabaciones de Google Meet
gws drive files list --params '{"q": "name contains \"Notas de Gemini\" and mimeType=\"application/vnd.google-apps.document\" and trashed=false", "orderBy": "modifiedTime desc", "pageSize": 5, "fields": "files(id,name,modifiedTime)"}'
```
Mostrar las 5 más recientes y preguntar cuál procesar.

**Caso 2: Archivo local** (`transcripts/archivo.md`) → Leer directamente.

**Caso 3: Keyword** → Buscar en Drive por nombre:
```bash
gws drive files list --params '{"q": "name contains \"KEYWORD\" and mimeType=\"application/vnd.google-apps.document\" and trashed=false", "orderBy": "modifiedTime desc", "pageSize": 5, "fields": "files(id,name,modifiedTime)"}'
```

**Si viene de Drive:**
1. Descargar contenido como texto plano:
```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' 2>&1 | python3 -c "
import json, sys
def extract_text(doc):
    content = doc.get('body', {}).get('content', [])
    text = []
    for element in content:
        if 'paragraph' in element:
            for el in element['paragraph'].get('elements', []):
                if 'textRun' in el:
                    text.append(el['textRun']['content'])
    return ''.join(text)
doc = json.load(sys.stdin)
print(extract_text(doc))
"
```
2. Guardar en `transcripts/` con nombre: `YYYY-MM-DD-tipo-descripcion.md`

**Verificar .processed.json:** Si ya se procesó, avisar y preguntar si reprocesar.

**Detectar tipo automaticamente:**
- Lunes → `planning`
- Jueves → `checkin`
- Otro día → `adhoc`

**Detectar semana ISO** de la fecha de la reunión.

### FASE 1: Extraccion paralela (3 subagentes)

Lanza TRES subagentes en paralelo. Cada uno recibe la transcripcion completa.

**Subagente 1 — DECISIONES Y ASIGNACIONES:**

Lee la transcripcion completa. Extrae:

1. **Decisiones clave** — Qué se decidió Y POR QUÉ (razon/contexto, no solo el hecho).
   Formato: "Se decidió X porque Y. Impacto: Z."
2. **Asignaciones para César** — Explícitas ("César, encárgate de...") e implícitas (temas donde César es el responsable natural).
   Formato: "Tarea: X | Contexto: Y | Prioridad implícita: Alta/Media/Baja"
3. **Cambios de estado** — Qué items pasaron a otro estado (QA, bloqueado, completado, etc.)
   Formato: "[PROYECTO] Item: estado anterior → estado nuevo"
4. **Citas de Ignacio** — Frases que señalen prioridad, urgencia o dirección estratégica.
   Formato: > "cita textual" — contexto de por qué importa
5. **Deadlines** mencionados — Explícitos o implícitos ("esta semana", "antes del viernes").
   Convertir a fecha absoluta.

**Subagente 2 — ESTADO DEL EQUIPO:**

Lee la transcripcion completa. Para CADA miembro del equipo mencionado, extrae:

| Campo | Qué buscar |
|-------|-----------|
| **Qué reportó** | Avance mencionado, demos, resultados |
| **Qué se le asignó** | Nuevas tareas o cambios de prioridad |
| **Bloqueos mencionados** | Dependencias, esperas, problemas técnicos |
| **Compromisos de entrega** | Fechas o hitos prometidos |
| **Cambios de scope/prioridad** | Si algo cambió para esta persona |

Miembros del equipo a rastrear:
- Samuel (Dev R&R)
- Faber (Dev R&R + App)
- Kevin (Dev App)
- Nicole (Product/Design)
- Julieth (QA)
- Ignacio (Head of Product)

Solo reportar lo que EXPLÍCITAMENTE se mencionó. No inventar ni inferir.

**Subagente 3 — INSIGHTS PE:**

Lee la transcripcion completa. Busca señales relevantes para un Principal Engineer:

1. **Dependencias entre equipos/personas** — ¿Quién depende de quién? ¿Hay cadenas de bloqueo?
2. **Riesgos técnicos mencionados** — Problemas de arquitectura, deuda técnica, integraciones frágiles.
3. **Patrones que se repiten** — ¿Se mencionó algo que ya se ha discutido antes? (Leer estado-semana.md sección "Aprendizajes PE" para contexto de lo ya registrado.)
4. **Oportunidades de mejora de proceso** — Cuellos de botella, pasos manuales automatizables, comunicación deficiente.
5. **Contexto de negocio nuevo** — Clientes, metas de expansión, cambios de estrategia, métricas mencionadas.

**CRITERIO ESTRICTO para sugerir aprendizajes:**
- ✅ Patrones recurrentes (>2 menciones en semanas distintas)
- ✅ Decisiones de negocio con impacto >1 mes
- ✅ Cambios de scope/rol/responsabilidad
- ✅ Dependencias entre equipos no documentadas
- ✅ Riesgos técnicos detectados
- ❌ NO sugerir: estados de tareas, asignaciones, notas de reunión, info ya en CLAUDE.md
- **Máximo 3 sugerencias por ejecución.** Calidad sobre cantidad.

### FASE 2: Escritura (subagente ESCRITOR)

Recibe los 3 outputs de Fase 1. Ejecuta estas acciones:

#### A) Generar resumen semanal

Crear archivo en `weekly/YYYY-WXX/{tipo}.md` con formato consistente:

```markdown
# {Tipo} — {Descripcion Reunión}
**Fecha:** YYYY-MM-DD (día) | **Semana:** WXX
**Participantes:** [lista]
**Fuente:** Drive — "[título]" | Transcript: transcripts/[archivo].md

---

## Decisiones Clave
[Del subagente 1, con razones]

## Asignaciones para César
[Del subagente 1, numeradas con contexto]

## Estado Reportado por Equipo
[Del subagente 2, por persona]

## Citas de Ignacio
[Del subagente 1, blockquotes]

## Cambios de Estado
[Del subagente 1, tabla o lista]
```

Si el archivo ya existe (reprocesando), preguntar: "¿Sobrescribir weekly/WXX/{tipo}.md?"

#### B) Actualizar estado-semana.md (MERGE inteligente)

**REGLAS CRÍTICAS DE MERGE:**
- **NUNCA reemplazar** contenido existente. SIEMPRE agregar/actualizar.
- **NUNCA tocar** sección "Tareas de StOn esta semana" (es manual de César).
- **Prefijos obligatorios:** `[FUERZA]`, `[ENGAGEMENT]`, `[R&R]`, `[SMART]`, `[APP]`
- **Iconos:** 🔴 Bloqueado | 🟡 En progreso | 🆕 Nuevo | ✅ Completado

Para cada sección:

| Sección | Acción de merge |
|---------|----------------|
| **Tickets FSV** | Agregar nuevos tickets. Actualizar estado de existentes. Mover completados a "Completados". |
| **Tareas en Progreso** | Agregar nuevas tareas. Agregar "Avance (fecha):" a existentes. Cambiar iconos de estado. |
| **Desarrollos en Progreso** | Agregar "Avance (fecha):" a existentes. Actualizar estado/fase. |
| **Estado del Equipo** | Actualizar cada persona con lo reportado en la reunión. Actualizar "Comprometió". |
| **Aprendizajes PE** | NO escribir directamente — se presentan al usuario en Fase 3. |
| **Completados** | Mover items terminados desde otras secciones. Agregar fecha. |
| **Notas de reuniones** | Agregar bloque con fecha y decisiones clave (máx 6 bullets). |
| **Resumen Rápido** | Regenerar tablas resumen reflejando cambios. Actualizar contadores. |
| **Frontmatter** | Actualizar: `updated`, `updated_by: "ingest"`, `items_active`, `items_blocked`, `items_completed_this_week`. Agregar wikilink a weekly. |

**Antes de escribir:** Leer estado-semana.md actual para hacer merge correcto.

#### C) Actualizar .processed.json

Agregar entrada:
```json
{
  "file": "YYYY-MM-DD-tipo-descripcion.md",
  "type": "planning|checkin|adhoc",
  "processed_at": "ISO-timestamp",
  "output": "weekly/YYYY-WXX/tipo.md",
  "drive_id": "ID-si-aplica",
  "drive_title": "título-si-aplica"
}
```

#### D) Wikilinks en Obsidian

En el resumen semanal (weekly/WXX/tipo.md), agregar wikilink al estado-semana:
```markdown
**Estado semana:** [[estado-semana]]
```

#### E) Git commit + push

```bash
cd /Users/cmoreno/Code/docs-projects
git add "_work/apprecio/estado-semana.md" "_work/apprecio/weekly/" "_work/apprecio/transcripts/" "_work/apprecio/.processed.json"
git commit -m "$(cat <<'EOF'
docs: ingest {tipo} W{XX} — {descripcion breve}
EOF
)"
git push
```

### FASE 3: Reporte + Sugerencias PE

Mostrar al usuario:

```
✅ Procesado: transcripts/{archivo}.md ({tipo}, W{XX})
📄 Resumen: weekly/YYYY-WXX/{tipo}.md
📝 Estado-semana actualizado (N cambios)

📋 CAMBIOS EN ESTADO-SEMANA:
  🆕 Nuevo: [PROYECTO] Tarea X
  🔄 Actualizado: [PROYECTO] Item Y → nuevo estado
  ✅ Completado: [PROYECTO] Item Z
  👥 Equipo: Samuel (actualizado), Faber (actualizado)

📌 ASIGNACIONES DETECTADAS PARA CÉSAR:
  1. [PROYECTO] Tarea — contexto (prioridad)
  2. [PROYECTO] Tarea — contexto (prioridad)
```

**Si hay insights PE (máx 3):**

```
💡 APRENDIZAJES PE DETECTADOS (sugerencias — tú decides)

  1. 🟡 "Descripción del insight"
     Valor: por qué es relevante para tu rol PE

  2. 🟡 "Descripción del insight"
     Valor: por qué es relevante

  3. ⚪ "Descripción descartada"
     NO sugiero guardar — razón

¿Cuáles guardo en Engram? [1,2 / todos / ninguno]
```

Solo guardar en Engram los que el usuario confirme. Topic key: `pe/learning/{slug-descriptivo}`

**Si hay transcripciones sin procesar:**

```
⚠️ N transcripciones sin procesar detectadas:
  - transcripts/YYYY-MM-DD-tipo.md (WXX)
  - transcripts/YYYY-MM-DD-tipo.md (WXX)
¿Procesar alguna? (Son de semanas anteriores — se archivan en su weekly/ 
correspondiente, NO actualizan estado-semana actual)
```

## Reglas Generales

- **NO consultar Linear.** Linear es dominio de `/today` y `/equipo`.
- **NO crear tareas en bd (beads).** Solo actualiza estado-semana.md.
- **NO tocar sección "Tareas de StOn".** Es manual de César.
- **NUNCA guardar en Engram automáticamente.** Siempre sugerir y esperar confirmación.
- **Merge, no reemplazar.** Agregar info nueva sin perder avances existentes.
- **Solo tareas de César** en secciones de tareas/desarrollos. Info de otros va en "Estado del Equipo".
- **Hora local:** America/Santiago (Chile). Convertir UTC si es necesario.
- **Si Obsidian CLI falla:** Fallback a Read/Write directo del path `/Users/cmoreno/Code/docs-projects/_work/apprecio/...`
- **Si Drive falla:** Informar error, ofrecer procesar archivo local de transcripts/.
- **Transcripciones viejas:** Si son de semanas anteriores, archivar en su weekly/ pero NO actualizar estado-semana actual (es snapshot de la semana en curso).
