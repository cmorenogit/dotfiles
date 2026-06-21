---
name: learn
description: Convierte un link (YouTube · Twitter · web) en una nota de estudio destilada en _personal/learning/. Solo a mano (/learn <url>).
disable-model-invocation: true
---

# learn — destilá un link en una nota de estudio

Convertí un link en un **documento para estudiar después**: una nota destilada, auto-suficiente y humanizada, con la transcripción **fuente** vinculada aparte. No es una descarga ni una transcripción cruda — es conocimiento listo para revisar.

`learn <url>` — una sola URL por corrida.

## Pipeline

Cada paso cierra en su criterio. No avances hasta cumplirlo.

### 1. Extraé la fuente

```sh
python3 ~/.claude/skills/learn/fetch.py "<url>"
```

Devuelve JSON con metadata (`title`, `author`, `date`, `duration_min`) y dos caminos:

- **`transcript_path`** (youtube/tiktok) → leé ese archivo: es la transcripción fuente.
- **`needs_webfetch: true`** (twitter/web) → traé el contenido con WebFetch sobre la `url`. Hilo de X → el hilo completo; artículo → el cuerpo sin nav ni ads.

*Done:* tenés el texto fuente completo + la metadata.

### 2. Destilá la capa A

Escribí la nota con el molde de [`REFERENCE.md`](REFERENCE.md): núcleo **fijo** (TL;DR · Resumen · Lectura crítica · Relacionado · Fuente) + cuerpo **adaptativo** según la densidad de la fuente.

Voz **humanizada** (inspirada en `voz`, sin acoplarla): español neutral y claro, que se lea de corrido — nunca bullets telegráficos ni jerga de máquina.

*Done:* el Resumen se sostiene solo — un lector entiende *todo lo importante* sin abrir la transcripción.

### 3. Lectura crítica

Aplicá tu lente: cuando la fuente **afirma** algo, marcá los claims a verificar con `⚠️`; siempre cerrá con la conexión a tu stack ("en mi stack esto importa porque…"). Un tutorial sin claims lleva solo la conexión.

*Done:* ningún claim decisivo queda presentado como hecho sin marca.

### 4. Vinculá la fuente

- Escribí la transcripción/contenido crudo en `~/Code/_vault/_personal/learning/<source>/_sources/<YYYY-MM-DD>-<slug>-fuente.md` (encabezado del molde + verbatim).
- En la nota, sección `## Fuente` con `[[<YYYY-MM-DD>-<slug>-fuente]]`.
- Generá `related:` buscando notas afines en `learning/` — wikilinks a archivos que **existen**, no inventados.

*Done:* la transcripción existe, la nota la enlaza, y cada `related` apunta a un archivo real.

### 5. Routeá y guardá

- Nota → `learning/<source>/<YYYY-MM-DD>-<slug>.md` (slug = kebab del título sin tildes; fecha = publicación de la fuente).
- Frontmatter estándar (schema en `REFERENCE.md`), `status: pending`.
- Commit + push (las notas viven en el vault, otro repo):

```sh
cd ~/Code/_vault && git add _personal/learning && \
  git commit -m "docs(learning): <source> — <título corto>" && \
  git pull --rebase && git push
```

*Done:* `git status` del vault limpio y pusheado.

## Alcance

v1: **YouTube · Twitter · Web**. TikTok y el video-dentro-de-tweet usan el camino whisper del extractor — habilitados, no garantizados. El puente a `/study` es **v2**: hoy la nota cierra en `status: pending`, tu cola de triaje.
