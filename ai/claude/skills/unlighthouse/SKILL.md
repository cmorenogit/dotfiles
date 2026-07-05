---
name: unlighthouse
description: Audita performance, accesibilidad, SEO y best-practices de TODO un sitio (no una sola URL) con Google Lighthouse, vía el CLI unlighthouse, y abre un reporte HTML interactivo local con el score por página. Úsalo para auditar el rendimiento de una web entera o varias rutas, comparar páginas, o un health-check de SEO/a11y. Para apps detrás de login (Beat BO, Fuerza, SL) arma la config de auth + rutas explícitas. Triggers — "/unlighthouse <url>", "auditá el performance de <sitio>", "corré lighthouse en todo <sitio>", "health-check de SEO/a11y de <web>".
---

# unlighthouse — auditoría Lighthouse de todo un sitio

Corre Google Lighthouse sobre TODAS las páginas de un sitio (no una URL suelta) y abre un **reporte HTML interactivo local** con el score por página de Performance, Accessibility, Best Practices y SEO. Herramienta madura de Harlan Wilton (ecosistema UnJS), MIT. Descarga Chromium/Puppeteer la primera vez (puede tardar).

## Reglas fijas de este skill

1. **Artefactos efímeros** — corré el comando desde el **directorio scratchpad de la sesión**. El reporte cae en `.unlighthouse/` ahí y no ensucia ningún repo.
2. **Secretos por env, NUNCA inline** — cookies de sesión, tokens y passwords van por variables de entorno (`process.env.X`) o flags en el momento, jamás hardcodeados en un config que pueda commitearse.
3. **El config con credenciales es efímero** — si generás `unlighthouse.config.ts`, vive en el scratchpad y lee secretos de `process.env`. No lo persistas en un repo ni en el vault.

## Caso 1 — sitio público (one-liner)

Web pública con enlaces/sitemap: el crawler descubre las rutas solo.

```sh
npx unlighthouse --site https://ejemplo.com
```

Abre el reporte interactivo en el navegador; esperá a que termine el scan.

## Caso 2 — apps detrás de login (Beat BO, Fuerza, SL)

Tus apps son SPAs con auth: el crawler **no** descubre rutas (no hay `<a href>` que seguir) y necesitan sesión. Dos piezas:

**a) Rutas explícitas** con `--urls` (rutas relativas; desactiva crawler y sitemap):

```sh
npx unlighthouse --site https://app.tu-dominio.com --urls /dashboard,/reportes,/config
```

**b) Auth** — elegí según cómo autentica la app:

| Mecanismo | Flag rápido | Equivalente en `unlighthouse.config.ts` |
|---|---|---|
| Cookie de sesión | `--cookies "session_id=$TOKEN"` | `cookies: [{ name, value, domain, path }]` |
| Bearer / header | `--extra-headers "Authorization:Bearer $TOKEN"` | `extraHeaders: { Authorization: ... }` |
| HTTP Basic | `--auth user:pass` | `auth: { username, password }` |
| Token en localStorage (SPA) | — | `localStorage: { auth_token: process.env.X }` |
| Login con formulario / OAuth / 2FA | — | `hooks.authenticate({ page })` (Puppeteer) |

Para flujos de login con formulario, generá `unlighthouse.config.ts` en el scratchpad. `npx unlighthouse` lo detecta solo desde el cwd:

```ts
import { defineUnlighthouseConfig } from 'unlighthouse/config'

export default defineUnlighthouseConfig({
  site: 'https://app.tu-dominio.com',
  // Sesión por cookie (lo más común en tus apps) — valor desde env, nunca inline:
  cookies: [
    { name: 'session', value: process.env.SESSION_TOKEN, domain: '.tu-dominio.com', path: '/' },
  ],
  // Login programático si no tenés la cookie a mano (corre una vez antes del scan):
  hooks: {
    async authenticate({ page }) {
      await page.goto('https://app.tu-dominio.com/login')
      await page.type('input[name="email"]', process.env.LH_USER)
      await page.type('input[name="password"]', process.env.LH_PASS)
      await Promise.all([page.click('button[type="submit"]'), page.waitForNavigation()])
    },
  },
  // Que la sesión persista entre páginas:
  lighthouseOptions: { disableStorageReset: true },
})
```

Luego: `npx unlighthouse --urls /dashboard,/reportes` desde el directorio del config.

## Acotar el scan

- `scanner.include: ['/articles/*']` — restringe a esas rutas (excluye el resto).
- `scanner.exclude: ['/api/*', '/admin/*', '/*.pdf']` — saltea patrones.

## Exportar (CI / sin abrir navegador)

Usá `unlighthouse-ci` para output de archivo en vez de la UI:

```sh
npx unlighthouse-ci --site https://ejemplo.com --reporter json     # → .unlighthouse/ci-result.json (score por página)
npx unlighthouse-ci --site https://ejemplo.com --reporter csv      # spreadsheet-friendly
npx unlighthouse-ci --site https://ejemplo.com --build-static      # dashboard HTML self-contained → servir con: npx sirv-cli .unlighthouse/
```

## Notas

- `--urls` usa rutas relativas y desactiva crawler + sitemap — es la vía robusta para SPAs.
- Complementa a `/lavish` (artefactos HTML del agente), no lo reemplaza: acá el HTML es el reporte de auditoría que genera la propia herramienta.
