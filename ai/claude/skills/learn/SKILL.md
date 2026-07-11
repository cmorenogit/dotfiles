---
name: learn
description: Convierte links (YouTube · X/Twitter · TikTok · Instagram · web) o contenido pegado en notas de estudio destiladas en _personal/learning/. Acepta varias URLs por corrida. Solo a mano (/learn <url…|texto>).
disable-model-invocation: true
---

# learn — destilá un link o contenido en una nota de estudio

Convertí un link **o un texto pegado** en un **documento para estudiar después**: una nota destilada, auto-suficiente y humanizada. No es una descarga ni una transcripción cruda — es conocimiento listo para revisar, con el link a la fuente original (si hay) para volver cuando lo necesites. La transcripción **no se guarda**: la nota es el único artefacto.

`learn <url>` o `learn <texto pegado>` — una fuente. `learn <url1> <url2> …` — varias: corré el pipeline **completo de una URL (pasos 1-4) antes de empezar la siguiente**, y un solo commit al final (paso 5) para todo el lote — así, si algo se corta, las notas ya escritas no se pierden.

## Pipeline

Cada paso cierra en su criterio. No avances hasta cumplirlo.

### 1. Conseguí la fuente

Mirá el argumento:

- **Es una URL** (`^https?://…`, sola) → extraela:
  ```sh
  python3 ~/.claude/skills/learn/fetch.py "<url>"
  ```
  Devuelve JSON con metadata y dos caminos: **`transcript_path`** (leé ese archivo — es el texto fuente efímero en `/tmp`) o **`needs_webfetch: true`** (solo `web` → traé el contenido con WebFetch sobre la `url`).
  - **`duplicate: true`** = ya existe una nota de este contenido (`existing_note` trae la ruta). No reproceses: reportá la nota existente y terminá.
  - **`description`** es el texto del autor (links a repos, docs, herramientas — materia prima de la sección Recursos); **`chapters`** son los timestamps del video, para referenciar minutos en la nota.
  - **Video (youtube/tiktok/instagram/X-con-video)**: se descarga y transcribe con whisper local, siempre — un video de 30 min toma ~3-5 min; esperá sin cortar (no pases timeouts chicos al Bash). `method: subtitles-fallback` significa que whisper falló y la fuente son auto-subs (menor calidad — mencionalo en Lectura crítica si hay claims dudosos).
  - **X/Twitter**: el JSON ya trae el texto del tweet (con links expandidos y tweet citado); si es un **X Article**, el cuerpo completo renderizado viene incluido en el transcript (usa la sesión de X de Zen). Si reporta error o el artículo no renderizó, pedile a César el texto pegado — no inventes contenido.
  - **Instagram**: best-effort — suele exigir login; si falla, reportá el motivo y ofrecé el modo paste.
- **Es contenido pegado** (texto, no una URL) → ya tenés la fuente: es el argumento mismo. No corras `fetch.py`. Es el **modo paste** (`type: paste`); seguramente no haya `url` ni `author` — está bien, son opcionales.

*Done:* tenés el texto fuente completo + la metadata que exista.

### 2. Destilá la nota

Escribí la nota con el molde de [`REFERENCE.md`](REFERENCE.md): núcleo **fijo** (TL;DR · Resumen · Lectura crítica · Relacionado · Fuente) + cuerpo **adaptativo** según la densidad de la fuente.

Voz **humanizada** (inspirada en `voz`, sin acoplarla): español neutral y claro, que se lea de corrido — nunca bullets telegráficos ni jerga de máquina.

Como la transcripción no se guarda, la nota es **auto-suficiente**: el Resumen sostiene el contenido por sí solo; para el detalle crudo está el link a la fuente original (si lo hay).

*Done:* un lector entiende todo lo importante sin abrir el link.

### 3. Lectura crítica

Aplicá tu lente: cuando la fuente **afirma** algo, marcá los claims a verificar con `⚠️`; siempre cerrá con la conexión a tu stack ("en mi stack esto importa porque…"). Un tutorial sin claims lleva solo la conexión.

*Done:* ningún claim decisivo queda presentado como hecho sin marca.

### 4. Relacioná

Generá `related:` buscando notas afines en `learning/` — wikilinks a archivos que **existen**, no inventados.

*Done:* cada `related` apunta a un archivo real.

### 5. Routeá y guardá

- Nota → `learning/<source>/<YYYY-MM-DD>-<slug>.md`. **La fecha es la de descarga (hoy), no la de publicación de la fuente.** slug = kebab del título sin tildes.
  - Con URL: `<source>` = `youtube` · `twitter` · `web` · `tiktok` · `instagram`.
  - **Contenido pegado:** `<source>` = `paste` y `type: paste` (cajón único — marca que no tiene fuente verificable).
- Frontmatter estándar (schema en `REFERENCE.md`), `status: pending`.
- Commit + push (las notas viven en el vault, otro repo):

```sh
cd ~/Code/_vault && git add "_personal/learning/<source>/<archivo>.md" && \
  git commit -m "docs(learning): <source> — <título corto>" \
    -- "_personal/learning/<source>/<archivo>.md" && \
  git pull --rebase --autostash && git push
```

*Done:* `git status` del vault limpio y pusheado.

## Alcance

v2: **YouTube · X/Twitter (texto, video y X Articles) · TikTok · Web · contenido pegado (paste)**, con whisper como transcriptor principal y varias URLs por corrida. Instagram habilitado best-effort (login wall frecuente). Límites conocidos: tweets borrados/protegidos y X Articles cuando Zen no tiene sesión de X → modo paste. El puente a `/study` sigue siendo futuro: la nota cierra en `status: pending`, tu cola de triaje.
