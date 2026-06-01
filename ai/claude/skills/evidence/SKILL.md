---
name: evidence
description: Graba evidencia en VIDEO de un flujo de UI con el Playwright CLI, en CUALQUIER proyecto (R&R/Bits, fuerza, smart-loyalty, engagement, o cualquier URL). Detecta el puerto de la app, escribe un spec del flujo, lo corre con video+trace, y convierte el video a .mp4 listo para adjuntar a un PR/Linear. Úsalo cuando el usuario quiera "grabar evidencia", "un video del flujo", "evidencia e2e", "probá X y grabá", "capturá la pantalla del flujo", "record evidence", o validar visualmente que un flujo funciona (no solo que la API responde). NO requiere agregar ningún MCP — usa el Playwright CLI ya instalado.
---

# Evidence — grabar video de un flujo con Playwright CLI

Genera evidencia visual reproducible (video + trace + screenshots) de un flujo de UI, usando el setup global `~/.config/playwright-evidence/`. Sirve para adjuntar a un PR/Linear o validar que **el usuario VE el resultado** (no solo que la API respondió 200/202).

**Setup global** (ya montado, NO recrearlo): Playwright `@playwright/test` 1.58.2 pineado (reusa los browsers del cache `~/Library/Caches/ms-playwright/`), config con `video: 'on'` + `trace: 'on'` + `screenshot: 'on'` y `baseURL` por env `PW_BASE_URL`.

## Flujo del skill (paso a paso)

### 1. Determinar el target (URL de la app)
- Si el usuario da una URL explícita → usala.
- App local en un **worktree R&R** (`back-pulse-cesar.*` / `app-rr-cesar.*`): leé el slot en `<worktree-back>/.worktree-slot` (o el `VITE_PORT` del `.env` del worktree). Puertos por slot:
  - backoffice Vite = `8080 + slot*100`
  - app Vite = `8081 + slot*100`
  - Supabase API = `54321 + slot*100`
- Otro proyecto (fuerza/sl/engagement/etc.): preguntá el puerto del dev server, o detectá con `lsof -nP -iTCP -sTCP:LISTEN | grep -E ':80[0-9][0-9]|:5173'`.
- **Confirmá que la app responde** antes de grabar: `curl -sf -o /dev/null "$URL" && echo OK` o `lsof -iTCP:<port> -sTCP:LISTEN`. Si no responde, avisá al usuario que levante la app (`supabase start` + `npm run dev` en el worktree) — no grabes contra una app caída.

### 2. Escribir el spec del flujo
- Ubicación: `~/.config/playwright-evidence/tests/<slug-del-flujo>.spec.ts` (efímero, NO va a ningún repo).
- Traducí los pasos que describe el usuario a Playwright: `page.goto('/ruta')`, `getByRole`/`getByTestId`/`getByText`, `click`, `fill`, y assertions `await expect(locator).toBeVisible()`.
- `baseURL` ya viene de `PW_BASE_URL` → usá **rutas relativas** (`page.goto('/scorecards')`).
- **REGLA anti "false sense of security"**: asserteá estado **VISIBLE en la UI** (texto, toast, navegación, elemento renderizado), NO solo respuestas de red. Un 200/202 de la API no prueba que el usuario vea el resultado (caso real R&R: API 202 sin efecto en pantalla).
- **Auth**: si la app requiere login, agregá el login al inicio del spec (fill credenciales → submit → esperar el app shell). Para R&R podés reutilizar credenciales seeded del repo (`tests/e2e/shared/fixtures/auth.fixture.ts`, p.ej. `admin-es@test.com` / `test123`); para otros proyectos, pedí las credenciales al usuario.

### 3. Correr y grabar
```bash
cd ~/.config/playwright-evidence
PW_BASE_URL="<url-de-la-app>" PW_SLOWMO=400 npx playwright test tests/<slug>.spec.ts --trace on
```
El config ya captura video + trace + screenshot. Los artefactos quedan en `~/.config/playwright-evidence/evidence/<test>/`.

**Duración / legibilidad del video** (el video dura lo que dura el test):
- `PW_SLOWMO=400` (250–600) ralentiza cada acción → flujo legible. Default para evidencia.
- Para detenerse en una pantalla clave, agregá `await page.waitForTimeout(1500)` en el spec (suma esos ms al video). Útil tras un submit para que se vea el resultado.
- La duración real la da CUÁNTO hace el flujo: más pasos = video más largo. Un login solo dura ~5s; un flujo completo, 20–40s.

### 4. Convertir el video a formato compartible (.mp4 por defecto)
```bash
WEBM=$(find ~/.config/playwright-evidence/evidence -name 'video.webm' | head -1)
ffmpeg -y -i "$WEBM" ~/.config/playwright-evidence/evidence/<slug>.mp4
# opcional, preview inline para un comentario de PR/Linear:
# ffmpeg -y -i "$WEBM" -vf "fps=10,scale=640:-1" ~/.config/playwright-evidence/evidence/<slug>.gif
```
(`ffmpeg` está instalado en el sistema — `/opt/homebrew/bin/ffmpeg`.)

### 5. Centralizar en el vault + entregar
Copiá el entregable al vault — carpeta **gitignored**, centralizada por proyecto/rama:
```bash
# proyecto: rr | fuerza | sl | engagement (mapping del repo); _adhoc si no hay repo (URL externa)
# rama:     git -C <worktree> branch --show-current ; _adhoc si no aplica
EVDIR=~/.config/playwright-evidence/evidence
DEST=~/Code/_vault/_evidence/<proyecto>/<rama>/$(date +%F)-<slug>
mkdir -p "$DEST"
cp "$EVDIR"/<slug>.mp4 "$DEST"/ 2>/dev/null
cp "$EVDIR"/*/trace.zip "$EVDIR"/*/*.png "$DEST"/ 2>/dev/null
```
Luego decile al usuario:
- La **ruta del `.mp4` en el vault** (`_evidence/<proyecto>/<rama>/<fecha>-<slug>/`) + cómo verlo:
  - `open <ruta>/<slug>.mp4` · `npx playwright show-report` · `npx playwright show-trace <ruta>/trace.zip` (o trace.playwright.dev)
- **NO commitear** — el vault ya ignora `_evidence/` (queda centralizado pero fuera del git).
- **Si el flujo FALLÓ**: el video igual sirve; entregá también el `test-failed-*.png` y el `error-context.md` (snapshot del accessibility tree al fallar) — dice la causa exacta sin re-reproducir.

## Configs avanzadas (research aplicado)
- **Resolución/nitidez** (ya en el config): viewport 1280x720 + `deviceScaleFactor:2` + `video.size` igualado → texto legible (sin downscale a 800px). Para tablas densas: `PW_WIDTH=1920 PW_HEIGHT=1080 …`. (fps/bitrate NO se controlan en Playwright; el `.mp4` lo hace ffmpeg.)
- **Duración/legibilidad**: `PW_SLOWMO=400` + `await page.waitForTimeout(ms)` en pantallas clave.
- **Recorrido visual (scroll arriba→abajo)**: para home/dashboard, recorré las secciones con `locator.scrollIntoViewIfNeeded()` + `waitForTimeout` entre cada una (más contexto + video más largo). Mejor que `window.scrollTo`, que falla si el scroll es de un contenedor interno de la SPA.
- **Screenshot página entera**: ya activo (`fullPage:true`). Tapar PII en una captura: `page.screenshot({ mask: [page.getByTestId('x')] })`.
- **Evidencia NO-visual** (payload de API, ID de transacción, PDF): dentro del test, `testInfo.attach('nombre', { body, contentType })` → aparece en el HTML report. Distingue "la API respondió" de "el flujo funciona".
- **App mobile** (la app R&R): en el spec, `import { devices } from '@playwright/test'` + `test.use({ ...devices['Pixel 7'] })` (Chromium con viewport/touch mobile; `iPhone 13` = WebKit, NO soporta cámara fake).
- **Centro de Evidencia R&R (GPS + cámara)**: la **cámara ya está habilitada** (fake stream en `launchOptions.args` del config). Para el **GPS**, en el spec: `test.use({ geolocation: { latitude: -12.0464, longitude: -77.0428 }, permissions: ['geolocation'] })` (ajustá las coords al país del flujo). Así el flujo de foto+GPS no se bloquea por los prompts del navegador.

## Cuándo NO usar este skill
- Para **regresión** con datos seeded en R&R, usá la suite del equipo (`scripts/run-e2e.sh`) — este skill es para evidencia rápida de UN flujo, no para mantener la suite de CI.
- Para **debug interactivo** (ver por qué falla en vivo: network/console), usá el Chrome DevTools MCP.

## Notas
- El setup vive en `~/.config/playwright-evidence/`. Si el dir no existe o falta `node_modules`, recrealo: `package.json` con `"@playwright/test": "1.58.2"`, `npm install`, y la `playwright.config.ts` con `video/trace/screenshot: 'on'` + `baseURL` por `PW_BASE_URL`.
- Pin a 1.58.2: usa el `chromium-1208` que ya está en el cache (no redescarga). Si cambia, `npx playwright install chromium`.
