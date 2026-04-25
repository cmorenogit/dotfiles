---
name: document
description: "Investiga y documenta funcionalidades, flujos o estado de implementaciones. Genera documentos compartibles orientados a la audiencia."
---

# /document — Documentation Generator

Investiga, analiza y genera documentación compartible sobre cualquier tema técnico o de producto. El documento se adapta a la audiencia y se guarda en el vault Tolaria con frontmatter tipado y relaciones (`belongs_to`, `related_to`).

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

Mapping a Tolaria knowledge graph del vault `docs-projects`:

| Directory pattern (cwd) | `belongs_to` (Project note) | Scope |
|-------------------------|-----------------------------|-------|
| `back-pulse-*`, `app-rr-*`, `pulse-dev` | `"[[rr]]"` | work |
| `fuerza/*` | `"[[fuerza]]"` | work |
| `engagement` | `"[[engagement]]"` | work |
| `smart-loyalty` | `"[[smart-loyalty]]"` | work |
| `agentes-hub-*` o cross-proyecto | `"[[_shared]]"` | work |
| `docs-projects` (vault directo) | preguntar al usuario | work |
| `personal/{prism,app-prompts,analisis,app-profile}` | `"[[<nombre-proyecto>]]"` | personal |
| (otro) | preguntar al usuario | depende |

**Vault root:** `/Users/cmoreno/Code/docs-projects` (symlink → iCloud Tolaria vault)
**Carpetas de salida (work):** `_work/apprecio/{modules,decisions,flows,analyses,prds,requests}/`
**Carpetas de salida (personal):** `_personal/projects/{nombre}/{modules,decisions,flows,analyses}/`

### 1.2 Detect document type (Tolaria type)

| Signal in request | `type` (Tolaria) | Carpeta destino | Focus |
|-------------------|:-:|-----------------|-------|
| módulo, servicio, API, endpoint | `Module` | `modules/` | Qué hace, endpoints, dependencias, estado |
| flujo, proceso, cómo funciona, paso a paso | `Flow` | `flows/` | Secuencia, actores, diagrama |
| feature, implementar, incorporar, nuevo | `Brief` | `analyses/` | Qué se hará, impacto, dependencias |
| bug, error, problema, fallo, incidente | `Incident` | `analyses/` | Qué pasó, causa, fix, prevención |
| decisión, por qué, trade-off, elegir | `Decision` | `decisions/` | Contexto, opciones, decisión tomada |
| verificar, existe, está implementado, check | `Analysis` | `analyses/` | Estado actual del código |
| solicitud, pedir, requerir | `Request` | `requests/` | Qué necesito, de quién, para cuándo |
| (default) | `Note` | `analyses/` | Análisis general |

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

## Phase 4: Save (vault Tolaria — única fuente de verdad)

### 4.1 Frontmatter Tolaria — siempre

Todo documento DEBE tener frontmatter Tolaria-nativo. Plantilla mínima:

```yaml
---
type: {Module|Flow|Decision|Analysis|Brief|Incident|Request|Note}
status: {Draft|Active|Approved|Archived}
belongs_to: "[[<project-or-module>]]"     # wikilink al Project/Module padre
related_to:                                # opcional, lista de wikilinks
  - "[[<related-1>]]"
  - "[[<related-2>]]"
audience:                                  # opcional, si --para fue usado
  - "[[<persona>]]"
date: YYYY-MM-DD                           # opcional, para Decision/Incident
---
```

**Reglas frontmatter:**
- `type` viene de Phase 1.2
- `belongs_to` viene de Phase 1.1
- `related_to` se infiere de los temas mencionados (otros módulos, decisiones, flujos)
- NO usar frontmatter `title:` — Tolaria toma el primer H1 del cuerpo como display title
- Wikilinks SIEMPRE entre comillas: `"[[name]]"` (sintaxis YAML válida)

### 4.2 Output path en el vault

**Naming:** kebab-case sin tildes, sin espacios, sin artículos. Max 50 chars.

| Tipo | Ruta destino (work) | Ruta destino (personal) |
|------|---------------------|-------------------------|
| `Module` | `_work/apprecio/modules/{slug}.md` | `_personal/projects/{proyecto}/modules/{slug}.md` |
| `Flow` | `_work/apprecio/flows/{slug}.md` | `_personal/projects/{proyecto}/flows/{slug}.md` |
| `Decision` | `_work/apprecio/decisions/{slug}-YYYY-MM.md` | `_personal/projects/{proyecto}/decisions/...` |
| `Analysis` / `Brief` / `Incident` | `_work/apprecio/analyses/{slug}-YYYY-MM.md` | `_personal/projects/{proyecto}/analyses/...` |
| `Request` | `_work/apprecio/requests/{destinatario}-YYYY-MM-DD.md` | n/a |
| `Note` (default) | `_work/apprecio/analyses/{slug}.md` | `_personal/{...}` |

**Ejemplos:** `flow-oauth-unificado.md`, `decision-recognition-budgets-2026-04.md`, `analysis-debug-challenges-2026-04.md`, `request-core-2026-04-25.md`.

Si la carpeta destino no existe, crearla.

### 4.3 Save to Engram (índice del knowledge graph)

```
mem_save(
  title: "doc/{slug}",
  topic_key: "doc/{slug}",
  type: "discovery",
  project: "{belongs_to value sin wikilinks}",
  content: "# {title}\n\n## Summary\n{resumen}\n\n## Vault: {full-vault-path}\n## Type: {Tolaria type}\n## belongs_to: {value}\n## related_to: {list}"
)
```

### 4.4 Compartir con Drive (manual, opt-in)

`/document` **NO sube a Drive automáticamente**. Si el usuario pide compartir explícitamente ("súbelo a Drive", "comparte con X"), usar el skill `gws-drive` ad-hoc para upload puntual. Vault es la fuente de verdad.

## Phase 5: Present

Show the user:

```
## Documento generado: {slug}

**Tipo:** {Tolaria type} | **belongs_to:** {project} | **Para:** {destinatario o "—"}

{resumen ejecutivo — 2-3 líneas}

**Vault:** `_work/apprecio/{categoria}/{slug}.md`
**Wikilinks creados:** {lista de related_to si aplica}

{Si --para: "Listo para compartir con {destinatario}. Para enviar por Drive: pídeme 'súbelo a Drive'."}
```

## Rules

- **Language**: Spanish for content, English for code/technical terms
- **File references**: Always `path/file.ts:line`
- **No placeholders**: Investigate fully, no TODO comments
- **Sections are conditional**: Only include sections that add value
- **Status icons**: ✅ (works), ❌ (missing), ⚠️ (partial)
- **Be honest**: If something doesn't exist or is broken, say it
- **Vault is canonical**: el vault Tolaria es la única fuente de verdad. Drive es opt-in manual
- **Tolaria-native frontmatter**: SIEMPRE incluir `type`, `belongs_to`. NO usar `title:` (primer H1 es el display title)
- **Wikilinks > paths**: en `related_to` y referencias internas, usar `[[wikilink]]` no `path/file.md`
- **Audience first**: When `--para` is set, the document is for THEM, not for César
