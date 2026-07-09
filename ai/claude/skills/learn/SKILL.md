---
name: learn
description: Convierte links (YouTube · Twitter · Instagram · TikTok · web) o contenido pegado en notas de estudio destiladas en _personal/learning/. Acepta varias URLs y modo cola (/learn inbox). Solo a mano (/learn <url…|texto|inbox>).
disable-model-invocation: true
---

# learn — destilá un link o contenido en una nota de estudio

Convertí un link **o un texto pegado** en un **documento para estudiar después**: una nota destilada, auto-suficiente y humanizada. No es una descarga ni una transcripción cruda — es conocimiento listo para revisar, con el link a la fuente original (si hay) para volver cuando lo necesites. La transcripción **no se guarda**: la nota es el único artefacto.

Tres formas de invocarlo:

- `learn <url>` o `learn <texto pegado>` — una fuente.
- `learn <url1> <url2> …` — varias URLs: corré el pipeline completo (pasos 1–4) por cada una, en secuencia; el commit (paso 5) es **uno solo al final** para todo el lote.
- `learn inbox` — **drena la cola de captura móvil** (ver "Modo inbox").

## Pipeline

Cada paso cierra en su criterio. No avances hasta cumplirlo.

### 1. Conseguí la fuente

Mirá el argumento:

- **Es una URL** (`^https?://…`, sola) → extraela:
  ```sh
  python3 ~/.claude/skills/learn/fetch.py "<url>"
  ```
  Devuelve JSON con metadata y dos caminos: **`transcript_path`** (youtube/tiktok → leé ese archivo, es la transcripción efímera en `/tmp`) o **`needs_webfetch: true`** (twitter/web → traé el contenido con WebFetch sobre la `url`).
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
cd ~/Code/_vault && git add _personal/learning && \
  git commit -m "docs(learning): <source> — <título corto>" && \
  git pull --rebase --autostash && git push
```

*Done:* `git status` del vault limpio y pusheado.

## Modo inbox — drenar la cola de captura móvil

La cola vive en `~/Code/_vault/_personal/learning/inbox.md` (la llena Hermes desde Telegram vía `inbox-add.sh`; formato: `- [ ] <url> — <fecha> — <nota opcional>`).

1. `cd ~/Code/_vault && git pull --rebase --autostash` — traé lo capturado.
2. Leé las líneas `- [ ]` de la sección Pendientes. Si no hay, reportá "cola vacía" y terminá.
3. Por cada línea, en secuencia: corré el pipeline (pasos 1–4) sobre su URL. Si la línea trae nota, usala como contexto en la Lectura crítica (es el "para qué lo guardé").
   - **Éxito** → escribí la nota y **eliminá la línea** del inbox (la historia queda en git).
   - **Falla** (sin transcripción, link muerto, login wall) → dejala como `- [!] <url> — <fecha> — error: <motivo breve>` y seguí con la siguiente. No reintentes en la misma corrida.
4. Un solo commit al final para notas + inbox: `docs(learning): inbox — <N> notas (<sources>)`, luego `git pull --rebase --autostash && git push`.
5. Reportá: procesadas / fallidas (con motivo) / pendientes restantes.

*Done:* inbox sin `- [ ]` procesables, vault limpio y pusheado.

## Alcance

v1: **YouTube · Twitter · Web · contenido pegado (paste)**. TikTok, Instagram y el video-dentro-de-tweet usan el camino whisper del extractor — habilitados, no garantizados (Instagram suele exigir login; si falla, queda `- [!]` para revisión manual). El puente a `/study` es **v2**: hoy la nota cierra en `status: pending`, tu cola de triaje.
