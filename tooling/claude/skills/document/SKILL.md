---
name: document
description: "Investiga y documenta funcionalidades, flujos o estado de implementaciones. Genera documentos compartibles orientados a la audiencia."
---

# /document — Documentation Generator

Investiga, analiza y genera documentación compartible sobre cualquier tema técnico o de producto. El documento se adapta a la audiencia y se guarda localmente + Drive.

## Arguments

```
/document <tema>                          # Documentación técnica completa
/document <tema> --para <destinatario>    # Adaptada a la audiencia
/document <tema> --tipo <tipo>            # Forzar tipo específico
```

**Ejemplos:**
```
/document modulo-entrenamiento
/document flujo-oauth-fuerza --para julieth
/document incentivos-entrenamientos --para ignacio
/document error-exportacion-excel --para soporte
/document decision-cherry-pick-incentivos
```

## Phase 1: Detect Context

### 1.1 Detect project from working directory

| Directory pattern | Proyecto | Drive folder |
|-------------------|----------|-------------|
| `fuerza` | Fuerza | `Trabajo/Fuerza/` |
| `back-pulse`, `app-rr` | R&R | `Trabajo/R&R/` |
| `engagement` | Engagement | `Trabajo/Engagement/` |
| `smart-loyalty` | Smart Loyalty | `Trabajo/Smart Loyalty/` |
| `docs-projects` | Apprecio (general) | `Trabajo/` |
| (otro) | Detectar del contenido | `Trabajo/` |

**Drive parent folder (Trabajo):** `12dpqhzzN1Mu9-Rcqryu0jp6lmBsau2gh`

### 1.2 Detect document type

| Signal in request | Type | Focus |
|-------------------|------|-------|
| módulo, servicio, API, endpoint | **Módulo/Servicio** | Qué hace, endpoints, dependencias, estado |
| flujo, proceso, cómo funciona, paso a paso | **Flujo** | Secuencia, actores, diagrama |
| feature, implementar, incorporar, nuevo | **Feature Brief** | Qué se hará, impacto, dependencias |
| bug, error, problema, fallo, incidente | **Incident Report** | Qué pasó, causa, fix, prevención |
| decisión, por qué, trade-off, elegir | **Decision Record** | Contexto, opciones, decisión tomada |
| verificar, existe, está implementado, check | **Investigación** | Estado actual del código |
| (default) | **Documentación** | Análisis general |

### 1.3 Detect audience from `--para`

| Destinatario | Rol | Nivel | Incluir | Excluir |
|-------------|-----|-------|---------|---------|
| **julieth** | QA | Funcional | Qué probar, escenarios, datos prueba, URLs QA, pasos de validación | Código fuente, arquitectura interna |
| **ignacio** | Producto | Negocio | Impacto usuario, timeline, riesgos, dependencias deploy, decisiones pendientes | Implementación, líneas de código |
| **cristian** / **core** | Core | Técnico-integración | APIs, contratos, payloads, endpoints que consumo/expongo | UI, frontend, negocio |
| **soporte** / **caco** | Soporte | Operativo | Queries MongoDB, colecciones, campos, cómo verificar datos, país | Arquitectura, código |
| **diana** / **saas** | SaaS | Usuario final | Qué cambió, cómo se ve, qué debe funcionar ahora | Todo lo técnico |
| (sin --para) | César | Técnico completo | Todo: código, arquitectura, endpoints, archivos, líneas | — |

## Phase 2: Investigate

### 2.1 Gather sources (in parallel where possible)

1. **Code**: Search the codebase for files related to the topic
   - Glob patterns for relevant files
   - Read code, trace flows between services
   - Identify endpoints, models, queries, schemas

2. **Engram**: Search for prior context
   ```
   mem_search("topic keywords", project: "detected-project")
   ```

3. **JIRA**: If a PM-XXXX is mentioned, fetch the ticket
   ```
   atlassian_jira_get_issue(issue_key: "PM-XXXX")
   ```

4. **Drive**: Search for existing documentation
   ```
   gws drive files list --params '{"q": "name contains 'topic' and trashed=false"}'
   ```

5. **Existing docs**: Check `docs/` folder in the project

### 2.2 Analyze and structure

- Map dependencies between services
- Identify data flow (input → processing → output)
- Note gaps, issues, or incomplete implementations
- Cross-reference with CLAUDE.md project knowledge

## Phase 3: Generate Document

### Template by type

All documents share this header:

```markdown
# [TÍTULO]

| Campo | Valor |
|-------|-------|
| **Fecha** | YYYY-MM-DD |
| **Proyecto** | [Fuerza / R&R / Engagement / Smart Loyalty] |
| **Tipo** | [Módulo / Flujo / Feature Brief / Incident / Decision / Investigación] |
| **Autor** | César Moreno |
| **Para** | [Destinatario o "Referencia técnica"] |
| **Servicios** | [lista de servicios involucrados] |
```

#### Módulo/Servicio

```markdown
## Resumen
[2-4 líneas: qué es, para qué sirve, estado actual]

## Arquitectura
[Diagrama mermaid si aplica — servicios, BDs, flujo de datos]

## Endpoints / API
| Método | Ruta | Descripción | Auth |
|--------|------|-------------|------|

## Modelo de Datos
| Colección/Tabla | Campos clave | BD |
|-----------------|-------------|-----|

## Dependencias
| Servicio | Tipo | Detalle |
|----------|------|---------|

## Estado Actual
| Aspecto | Estado | Observación |
|---------|--------|-------------|
| Implementado | ✅/❌/⚠️ | |
| Funcional | ✅/❌/⚠️ | |
| Completo | ✅/❌/⚠️ | |

## Notas
[Contexto adicional, decisiones, caveats]
```

#### Flujo

```markdown
## Resumen
[Qué proceso describe este documento]

## Actores
| Actor | Rol en el flujo |
|-------|----------------|

## Flujo Principal
[Diagrama mermaid: sequenceDiagram o flowchart]

## Pasos Detallados
### 1. [Paso]
- **Quién**: [actor]
- **Qué**: [acción]
- **Dónde**: [servicio/archivo]
- **Datos**: [qué se envía/recibe]

## Casos Especiales
[Errores, timeouts, edge cases]

## Notas
```

#### Feature Brief

```markdown
## Resumen
[Qué se quiere hacer y por qué]

## Contexto
[Situación actual, problema que resuelve]

## Propuesta
[Qué se va a implementar — alto nivel]

## Impacto
| Servicio | Cambio | Riesgo |
|----------|--------|--------|

## Dependencias
| Qué necesito | De quién | Estado |
|-------------|----------|--------|

## Plan de Implementación
1. [Paso 1]
2. [Paso 2]

## Configuración QA / Producción
| Variable | QA | Producción |
|----------|-----|-----------|

## Notas
```

#### Incident Report

```markdown
## Resumen
[Qué pasó, cuándo, impacto]

## Timeline
| Hora | Evento |
|------|--------|

## Causa Raíz
[Qué provocó el problema]

## Fix Aplicado
[Qué se hizo para resolverlo]

## Archivos Afectados
| Archivo | Línea | Cambio |
|---------|-------|--------|

## Prevención
[Qué hacer para que no vuelva a pasar]
```

#### Decision Record

```markdown
## Contexto
[Situación que requiere una decisión]

## Opciones Evaluadas
| Opción | Pros | Contras |
|--------|------|---------|

## Decisión
[Qué se decidió y por qué]

## Consecuencias
[Qué implica esta decisión — trade-offs aceptados]
```

### Audience adaptation

When `--para` is specified, apply these transformations AFTER generating the base document:

**Para julieth (QA):**
- Remove code blocks and file:line references
- Add section `## Escenarios de Prueba` with table: | Escenario | Pasos | Resultado esperado |
- Add section `## Datos de Prueba` with specific values to test
- Add section `## URLs` with QA environment links
- Use business terms, not technical

**Para ignacio (Producto):**
- Remove all code, architecture internals
- Lead with business impact and user-facing changes
- Add section `## Decisiones Pendientes` if any
- Add section `## Timeline / Dependencias de Deploy`
- Keep it under 1 page if possible

**Para cristian/core:**
- Focus on API contracts and integration points
- Include request/response payloads
- Add section `## Lo que necesito de Core` with specific asks
- Keep code examples relevant to the integration boundary

**Para soporte:**
- Include MongoDB queries to verify/fix
- Specify collections, fields, country-specific behavior
- Add section `## Cómo verificar` with step-by-step
- Add section `## Queries útiles` with copy-pasteable queries

## Phase 4: Save

### 4.1 Local — always

Save to `docs/documentation/` in the current project:

```
docs/documentation/[NOMBRE-EN-MAYUSCULAS].md
```

Naming rules:
- UPPERCASE with hyphens
- Remove articles (el, la, los, de, del, con)
- Max 50 chars
- Examples: `FLUJO-OAUTH-FUERZA.md`, `MODULO-ENTRENAMIENTOS.md`, `DECISION-CHERRY-PICK.md`

If `docs/documentation/` doesn't exist, create it.

### 4.2 Drive — always

Upload to project subfolder in `Trabajo/`:

1. **Check if project folder exists** in Drive (`Trabajo/`):
   ```
   gws drive files list --params '{"q": "name=\"{Proyecto}\" and \"12dpqhzzN1Mu9-Rcqryu0jp6lmBsau2gh\" in parents and mimeType=\"application/vnd.google-apps.folder\" and trashed=false"}'
   ```

2. **If not exists, create it:**
   ```
   gws drive files create --body '{"name": "{Proyecto}", "mimeType": "application/vnd.google-apps.folder", "parents": ["12dpqhzzN1Mu9-Rcqryu0jp6lmBsau2gh"]}'
   ```

3. **Check for `Documentación/` subfolder**, create if missing.

4. **Upload the file:**
   ```
   gws drive files create --body '{"name": "{filename}", "parents": ["{doc-folder-id}"]}' --upload docs/documentation/{filename}
   ```

**Drive structure created on demand:**
```
Trabajo/
├── Fuerza/
│   └── Documentación/
│       ├── MODULO-ENTRENAMIENTOS.md
│       └── FLUJO-OAUTH.md
├── R&R/
│   └── Documentación/
│       └── FEATURE-CHALLENGES.md
└── ...
```

### 4.3 Save to Engram

```
mem_save(
  title: "doc/{project}/{topic-slug}",
  topic_key: "doc/{project}/{topic-slug}",
  type: "discovery",
  content: "# {title}\n\n## Summary\n{resumen}\n\n## Files\n{archivos principales}\n\n## Drive: {drive-file-id}"
)
```

## Phase 5: Present

Show the user:

```
## Documento generado: {NOMBRE}

**Tipo:** {tipo} | **Para:** {destinatario}

{resumen ejecutivo — 2-3 líneas}

**Guardado en:**
- Local: `docs/documentation/{NOMBRE}.md`
- Drive: `Trabajo/{Proyecto}/Documentación/{NOMBRE}.md`

{Si --para: "Listo para compartir con {destinatario}."}
```

## Rules

- **Language**: Spanish for content, English for code/technical terms
- **File references**: Always `path/file.ts:line`
- **No placeholders**: Investigate fully, no TODO comments
- **Sections are conditional**: Only include sections that add value
- **Status icons**: ✅ (works), ❌ (missing), ⚠️ (partial)
- **Be honest**: If something doesn't exist or is broken, say it
- **Drive is silent**: Don't show upload/download details, only errors
- **Audience first**: When `--para` is set, the document is for THEM, not for César
