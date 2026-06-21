---
name: transcripcion
description: Trae el VERBATIM (no el resumen) de una reunión de Google Meet a partir de una descripción en lenguaje natural — persona, título o fecha ("el weekly del lunes", "la de Nicole", "Ignacio del 16"). Resuelve, desambigua si hay varias, extrae la pestaña "Transcripción" completa a un archivo efímero y queda lista para que le preguntes. Triggers — "/transcripcion <desc>", "traeme la transcripción de <X>", "qué se dijo en la reunión de <X>", "el verbatim del weekly".
---

# transcripcion — el verbatim, no el resumen

Visor on-demand de transcripciones de Meet. Vos describís la reunión; esto trae el **verbatim completo** (la pestaña "Transcripción", no las "Notas de Gemini" que son solo el resumen) y lo deja listo para analizar. **No vuelca el crudo al chat** — trabajás sobre un archivo en `/tmp`.

El motor determinista es `transcripcion.py` (vive junto a este archivo). Vos —el modelo— solo interpretás la query y orquestás. El script garantiza las dos cosas que rompían el flujo manual: lee las **pestañas** (`includeTabsContent`) y filtra el ruido del CLI.

## Flujo

1. **Interpretá la query** → separá dos cosas:
   - **nombre** (persona / título / palabra clave): "Nicole", "Weekly", "eventos automáticos".
   - **fecha** (relativa o absoluta) → convertila a `YYYY-MM-DD` en **GMT-5** usando la fecha de hoy del contexto. "el lunes" = el lunes más reciente; "ayer"; "del 18" = día 18 del mes en curso.
   - Conceptos sin reflejo en el título (p.ej. "weekly" matchea "Weekly - Product Team Meet"; pero si no hay match de nombre, caé a solo-fecha).

2. **Listá candidatos:**
   ```sh
   python3 ~/.claude/skills/transcripcion/transcripcion.py list \
     --name "Weekly" --after 2026-06-15 --before 2026-06-16
   ```
   `--name`, `--after`, `--before` son todos opcionales. Búsqueda **global** (incluye reuniones de otros compartidas con vos: los weeklies son de Ignacio).

3. **Resolvé según `count`:**
   - **1** → llamá `get <id>` directo.
   - **>1** → mostrá una **lista numerada** `nº · título · fecha GMT-5 hora · owner` y **esperá** que César elija. No extraigas antes.
   - **0** → decílo y sugerí ampliar (menos términos, o dar fecha/persona).

4. **Extraé el verbatim:**
   ```sh
   python3 ~/.claude/skills/transcripcion/transcripcion.py get <DOC_ID>
   ```
   Devuelve `{path, title, date, duration, turns, chars, tab}` y escribe el `.md` en `/tmp`.

5. **Confirmá** con este formato (la metadata ES la prueba de que trajo todo):
   ```
   ✓ <título> — <owner>
     <día dd mmm aaaa GMT-5> · <duración> · <turns> turnos · <chars> chars
     verbatim → <path>
     Listo — preguntame lo que quieras del verbatim.
   ```

6. **Análisis on-demand:** para responder ("qué decidió Ignacio sobre X"), **leé el archivo `/tmp`** (o las secciones relevantes con grep/offset si es enorme) y respondé **citando el verbatim**. Nunca pegues el verbatim entero en el chat.

## Reglas

- **Verbatim, no resumen.** Si `tab` vuelve como "… (sin pestaña Transcripción)", avisá: esa reunión solo tiene resumen (o el verbatim no se generó).
- **GMT-5 siempre.** El script ya normaliza la hora (los docs de Ignacio vienen en WEST/WET).
- **Efímero.** El `.md` va a `/tmp`, no al vault. Si de la transcripción sale una decisión/aprendizaje que valga, **eso** se persiste con `/vault` — el verbatim crudo no.
- **Ante duda, desambiguá.** Nunca extraigas la reunión equivocada en silencio; si hay varias, mostralas y que César elija.

## Fuera de alcance (follow-ups)

Scan standalone del archivo histórico · aliases ("weekly" = recurrente fija) · búsqueda por **contenido** (grep local, no solo título) · participantes en la metadata.
