---
description: Absorbe cualquier URL/archivo → resumen + análisis + nota Obsidian conectada
---

# /learn — Absorber conocimiento

Recibe una URL o archivo compatible con `summarize`, lo procesa y genera una nota de conocimiento en Obsidian con análisis profesional y conexiones al cerebro existente.

**Input:** `$ARGUMENTS` (URL de YouTube, artículo, PDF, archivo local, etc.)

## Flujo de ejecución

### FASE 1: Extracción paralela (Bash directo, NO subagentes)

Lanza TRES comandos Bash en PARALELO (NO usar Agent — usar Bash tool directamente):

**Comando 1 — EXTRACTOR:**
```bash
summarize $ARGUMENTS --extract --format md 2>&1
```
Captura el contenido raw. Es gratis (sin LLM). Si es tweet y falla, usar fallback:
```bash
# Extraer usuario e ID de la URL de X/Twitter
curl -s "https://api.fxtwitter.com/USUARIO/status/TWEET_ID" 2>&1 | python3 -m json.tool
```

**Comando 2 — RESUMIDOR:**
```bash
summarize $ARGUMENTS --cli claude --length long --language es 2>&1
```
Si es tweet y summarize falla, el EXTRACTOR ya trajo el contenido vía fxtwitter — omitir este paso y usar el raw content como base para el analista.

**Comando 3 — CONTEXTO VAULT:**
```bash
# Tags existentes más usados (si Obsidian corre)
obsidian tags vault=docs-projects counts sort=count format=json 2>&1 | head -50

# Buscar notas relacionadas (3-5 keywords del tema)
obsidian search vault=docs-projects query="KEYWORD1" limit=10 format=json 2>&1
obsidian search vault=docs-projects query="KEYWORD2" limit=10 format=json 2>&1
obsidian search vault=docs-projects query="KEYWORD3" limit=10 format=json 2>&1
```

Si Obsidian no está corriendo, usar fallback:
```bash
grep -roh '#[a-zA-Z0-9_-]*' /Users/cmoreno/Code/docs-projects/_personal/learning/ --include="*.md" | sort | uniq -c | sort -rn | head -30
grep -rl "KEYWORD1" /Users/cmoreno/Code/docs-projects/_personal/learning/ --include="*.md" | head -10
grep -rl "KEYWORD2" /Users/cmoreno/Code/docs-projects/_drive/Conocimiento/ --include="*.md" | head -10
```

IMPORTANTE: Los 3 comandos Bash se lanzan en PARALELO en el mismo mensaje. NO como Agents.

### FASE 2: Análisis (subagente ANALISTA — el ÚNICO Agent del flujo)

Con el raw content + resumen + contexto del vault, lanzar UN subagente que genera el documento completo.

El subagente recibe:
- El resumen de summarize (output del comando 2)
- El contenido raw (output del comando 1, primeros 5000 chars para capturar citas)
- Las notas relacionadas encontradas (output del comando 3)
- Los tags existentes del vault

**Genera este documento Markdown:**

```markdown
---
title: "[Título del contenido]"
url: "[URL fuente]"
video_id: "[ID si es YouTube, sino omitir]"
channel: "[Canal/Autor si aplica]"
duration_minutes: [duración en minutos si aplica]
upload_date: "[fecha de hoy YYYY-MM-DD]"
processed_at: "[timestamp ISO actual]"
type: "[youtube|article|pdf|audio|video|tweet]"
status: "pending"
tags:
  - [tag1 - REUTILIZAR tags existentes del vault cuando aplique]
  - [tag2]
  - [tag3]
related:
  - "[[nombre-nota-relacionada-1]]"
  - "[[nombre-nota-relacionada-2]]"
---

# [Título]

- **Fuente:** [URL](URL)
- **Fecha de Procesamiento:** YYYY-MM-DD
- **Tipo:** YouTube | Artículo | PDF | Tweet | Audio | Video

## TL;DR
[1-2 líneas. La idea en 15 segundos. Para cuando reabras la nota en 3 meses.]

## Resumen Ejecutivo
[El resumen que devolvió summarize, limpio y bien formateado.
Debe capturar la TESIS CENTRAL del contenido, no solo listar datos.
Empezar con "De qué trata" en 1-2 líneas, luego desarrollar.]

## Datos Clave
[SOLO para contenido técnico o con datos cuantitativos.
Tabla con números, specs, costos, comparativas.
Omitir para tweets de opinión o contenido sin datos duros.]

## Puntos Clave
[3-7 bullets según extensión (tweet=3, video largo=7).
Cada uno debe tener contexto, no solo el dato suelto.]

## Citas Destacadas
[1-3 quotes textuales del contenido que anclen la nota.]

> "La cita textual aquí"
> — *Contexto: por qué importa*

## Aplicabilidad Profesional

### ¿Cambia algo que hago hoy?
[Responder HONESTAMENTE. Si la respuesta es "no mucho", decirlo.
Para cada punto: Qué es → por qué me importa → qué haría concretamente.
Comparar contra el stack actual:
- Claude Code Max como herramienta principal
- Obsidian como knowledge base
- MacBook 64GB + Mac Mini como hardware
- Apprecio: R&R, Fuerza, Smart Loyalty, Engagement (Supabase + Edge Functions)]

### Donde NO aplica
[Ser honesto sobre limitaciones.]

### Veredicto de aplicabilidad
[Una línea con emoji + calificación + razón]
🟢 **Transformador** — cambia cómo trabajo día a día
🟡 **Complementario** — útil en casos específicos, no cambia el flujo principal
🔴 **No aplica** — interesante pero no cambia nada para mí ahora

## Qué NO hacer
[Anti-patrones del contenido. Omitir si no hay.]

## Action Items
- [ ] [Acción + POR QUÉ + CONTEXTO + CUÁNDO (esta semana / próximo sprint / cuando aplique)]
[Solo si hay algo genuinamente accionable. No inventar.]

## Conexiones
[Links a notas relacionadas encontradas en el vault.
Para CADA conexión, explicar POR QUÉ se relaciona.]
- [[nota-1]] — por qué se relaciona

## Mi Veredicto
[Opinión en primera persona. ¿Valió mi tiempo?
¿Cambió cómo pienso? ¿Se lo recomendaría a alguien del equipo?
2-4 líneas. Directo, honesto.]

## Fuente
Resumen generado con `summarize --cli claude` | Procesado: [fecha]
```

**Reglas del ANALISTA (CRÍTICAS — seguir al pie de la letra):**

### Tono y voz
- Escribir en PRIMERA PERSONA. Como si César explicara a un colega qué aprendió.
- No "es relevante" → "me sirve para X" o "no me cambia nada".
- No sonar a reporte de consultoría. Sonar a ingeniero procesando información.
- Ser brutalmente honesto. Si algo no aplica, decirlo.

### Aplicabilidad
- Empezar SIEMPRE con "¿Esto cambia algo que hago hoy?" — responder honestamente.
- Si mencionas Apprecio, nombrar el módulo/servicio/repo exacto. Si no hay ninguno concreto, NO forzar mencionar Apprecio.
- SIEMPRE comparar contra el stack actual (Claude Code Max, Obsidian, MacBook 64GB).
- Incluir "Donde NO aplica".
- Cerrar con veredicto emoji (🟢/🟡/🔴) + una línea.

### Tags y conexiones
- Tags: SIEMPRE reutilizar tags existentes del vault cuando el tema coincida. Crear nuevos solo si es un tema genuinamente nuevo.
- Wikilinks `[[...]]`: Solo crear links a notas que EXISTAN en el vault (verificadas en Fase 1). Usar TODOS los resultados relevantes.
- Cada conexión debe explicar POR QUÉ se relaciona.

### Contenido
- TL;DR: SIEMPRE incluir. 1-2 líneas, la idea en 15 segundos.
- Datos Clave: Solo para contenido técnico/cuantitativo. Tabla. Omitir si no hay datos duros.
- Citas: Extraer 1-3 quotes memorables del raw content.
- Action items: Cada uno con QUÉ + POR QUÉ + CONTEXTO + CUÁNDO. Si no hay action items genuinos, omitir.
- "Qué NO hacer": Capturar anti-patrones. Si no hay, omitir.
- Proporcional: tweet = nota corta. Video 1h = nota completa. No inflar.
- Idioma: Todo en español excepto términos técnicos.

### FASE 3: Escritura en Obsidian

**Determinar subcarpeta según tipo:**
- YouTube/Video → `_personal/learning/youtube/`
- Tweet/Artículo/Web/PDF/Audio → `_personal/learning/content/`

**Nombre del archivo:** `YYYY-MM-DD-titulo-slug.md` (slug: lowercase, sin acentos, hyphens, max 60 chars)

Usar la herramienta Write para crear el archivo en:
`/Users/cmoreno/Code/docs-projects/[subcarpeta]/[archivo].md`

**Post-creación (si Obsidian corre):**
```bash
obsidian file vault=docs-projects path="[ruta-relativa]" 2>&1
obsidian daily:append vault=docs-projects content="📚 Aprendí: [[titulo-nota]] — [1 línea de qué trata]" 2>&1
```

### FASE 4: Commit y push

```bash
cd /Users/cmoreno/Code/docs-projects
git add "_personal/learning/[subcarpeta]/[archivo].md"
git commit -m "docs: add learning note — [titulo-slug]"
git push 2>&1
```

**Reglas del commit:**
- Mensaje: `docs: add learning note — [titulo-slug]`
- Solo agregar el archivo de learning creado
- NO agregar otros archivos del vault
- Si push falla, reportar el error pero NO reintentar

### FASE 5: Reporte al usuario

```
✅ Nota creada: _personal/learning/[subcarpeta]/[archivo].md

📌 Tags: #tag1 #tag2 #tag3
🔗 Conexiones: N notas vinculadas
📝 Action items: N pendientes (o "ninguno")
🟢/🟡/🔴 Veredicto: [una línea]
📅 Registrado en daily note (o "Obsidian no corriendo")
🔄 Commit + push: [hash corto] → origin
```

## Reglas generales

- NO modificar notas existentes del vault
- NO crear carpetas nuevas — usar las que ya existen
- FASE 1 usa Bash directo (NO Agent) — esto es CRÍTICO para velocidad
- Solo FASE 2 (ANALISTA) usa Agent
- Si Obsidian no está corriendo → escribir archivo directo + grep para búsqueda
- Si summarize falla, reportar el error al usuario con el stderr
- Todo el output al usuario debe ser en español
- El vault se llama `docs-projects` y está en `/Users/cmoreno/Code/docs-projects/`
