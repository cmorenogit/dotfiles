# Identidad — César Moreno

## Identidad y rol
- Ingeniero Principal en Apprecio — referente técnico cross-equipo (Producto, Core, Soporte)
- Jefe directo: Ignacio Valdovinos (Jefe de Producto)
- Scope: R&R, Fuerza (incluye Incentivos), Smart Loyalty, Engagement
- NO soy Tech Lead ni Manager (no gestiono personas)

## Equipo Apprecio

**Mi equipo (Producto):**
- Ignacio Valdovinos — Jefe de Producto (despliega a producción)
- Julieth — QA principal (intermediaria con Soporte; valida en QA + países)
- Samuel, Faber, Kevin — Devs
- Nicole — Producto (R&R y app)

**Otros equipos clave:**
- Soporte (Caco): Paulina deriva tickets, ejecutan queries de BD
- Core (Jesús Leiva): Cristian (Incentivos), Fabricio (Dbox/transacciones)
- SaaS: Diana reporta errores

Detalle (scopes, flujos cross-equipo): `~/Code/_vault/_work/apprecio/_shared/team-roster.md`

## Canales de comunicación (por orden de preferencia)
1. **Linear** — medio principal para comunicación laboral en línea (issues, comentarios, contexto de trabajo)
2. **Google Chat** — DMs laborales y conversaciones que no van en Linear
3. **Email** — solo cuando se solicita explícitamente envío por email

---

# Cómo trabajar conmigo

## Comunicación
- Comunicación: español. Código, commits, comentarios y términos técnicos: inglés.
- Tono: arquitecto senior — trade-offs + recomendación, cero redundancia.
- Estructura: tablas > listas > párrafos.
- Longitud: simple <50 palabras, técnica <150, arquitectura sin límite.
- Referencias a código: siempre `ruta/archivo.ts:línea`.
- Explicar cuando aporta el "¿por qué?", trade-offs no evidentes, alternativas. NO explicar: comandos estándar, conceptos básicos, info ya en CLAUDE.md/AGENTS.md del proyecto.
- NUNCA firmas, atribuciones, watermarks ni texto tipo "Made with Claude/AI".

---

# Framework de decisión técnica

Ante cualquier decisión técnica, evaluar en este orden:

1. **Resultado de negocio** — ¿qué métrica o resultado mueve esto?
2. **Simplicidad** — ¿es la solución más simple que logra ese resultado?
3. **Riesgo** — ¿qué puede salir mal y cómo se mitiga?
4. **Mantenibilidad** — ¿el equipo puede mantenerlo sin mí?

---

# Reglas de desarrollo

## Scope de cambios
- Un commit = un propósito. No mezclar refactors con features.
- Si encuentro tech debt, reportarlo pero no arreglarlo sin permiso.

## Verificación
- Antes de refactorizar, confirmar que el código actual funciona.
- No asumir que un error reportado es el único problema.

## Restricciones
- No generar código placeholder (`// TODO: implement`) — implementar completo o preguntar.
- No modificar archivos de configuración del proyecto (env, dependencies, build) sin confirmación.
- No inventar APIs, endpoints, schemas o estructuras — verificar que existen.
- No eliminar código sin entender su propósito.
- No silenciar warnings/errors del compilador o linter sin justificación.

## Git
Conventional Commits en inglés: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.

---

# Repos y mapping al vault

| Proyecto | Repo local | Vault path |
|---|---|---|
| R&R | `~/Code/work/rr-project/` | `_work/apprecio/projects/rr/` |
| App mobile | `~/Code/work/app-project/` | `_work/apprecio/projects/app/` |
| Fuerza | `~/Code/work/fuerza-project/` | `_work/apprecio/projects/fuerza/` |
| Smart Loyalty | `~/Code/work/sl-project/` | `_work/apprecio/projects/sl/` |
| Engagement | `~/Code/work/engagement-project/` | `_work/apprecio/projects/engagement/` |

**⚠️ Wrappers multi-repo:** `fuerza-project/`, `sl-project/`, `engagement-project/` son directorios LOCAL-ONLY sin git remote. Cada subdirectorio adentro es un repo git independiente. **SIEMPRE** `cd` al subdirectorio antes de operaciones git — nunca commit/push desde el wrapper.

**Mapping cwd → vault project** (para escribir docs):

| cwd patrón | Vault destino | `project:` |
|---|---|---|
| `rr-project/*` | `_work/apprecio/projects/rr/` | `rr` |
| `app-project/*` | `_work/apprecio/projects/app/` | `app` |
| `fuerza-project/*` | `_work/apprecio/projects/fuerza/` | `fuerza` |
| `sl-project/*` | `_work/apprecio/projects/sl/` | `sl` |
| `engagement-project/*` | `_work/apprecio/projects/engagement/` | `engagement` |
| `_bruno/*`, `_services/*`, cross-project | `_work/apprecio/_shared/` | `_shared` |
| `personal/*` | `_personal/...` | `_personal` |

**Ambientes:** QA + Producción. Sin staging, excepto R&R (dev/staging/prod via Supabase + Cloudflare).

Detalle (stacks, GitHub orgs, repos por servicio): `~/Code/_vault/_work/apprecio/_shared/repos-and-stacks.md`

---

# Flujo FSV (Soporte/Mantenimiento — aplica a Fuerza, Smart Loyalty, Engagement)

```
Diana (SaaS) detecta error
  → Julieth crea issue Linear + califica FSV
    → César investiga (info BD vía Soporte si necesario)
      → PR → Julieth valida QA + países → Ignacio despliega prod
        → Julieth confirma a Diana → cierre
```

**Destinatarios por tipo de PR:**

| Tipo | Principal | CC |
|---|---|---|
| Desarrollo general | @Julieth Ruiz | @Ignacio Valdovinos |
| Despliegues Fuerza/SL | @Ignacio Valdovinos | @Julieth Ruiz |
| PRs Incentivos | @Cristian | @Ignacio Valdovinos |

Detalle (templates Issue Linear/PR/Hilo/Mensaje, reglas de formato): `~/Code/_vault/_work/apprecio/_shared/process-fsv.md`

---

# Beads — `bd` (aplica si `bd` disponible y `.beads/` presente)

**Todo issue tracking en repos de trabajo usa bd.** No markdown TODOs, no TaskCreate, no external trackers cuando hay `.beads/`.

**Reglas esenciales:**
- Prefijo monorepo: `bd create "[servicio] Titulo" -t bug -p 1`
- Siempre `--json` flag para uso programático
- Link discovered work: `--deps discovered-from:<parent-id>`
- Commit `.beads/issues.jsonl` junto con cambios de código
- `bd ready` antes de preguntar "qué hago?"

**Inicialización proyecto nuevo:**
```bash
bd config set dolt.auto-commit off
cat > .beads/config.yaml <<'YAML'
auto-start-daemon: true
backup:
  enabled: false
  git-push: false
dolt.auto-commit: "off"
YAML
```

**Prioridades:** `0` Critical | `1` High | `2` Medium (default) | `3` Low | `4` Backlog
**Tipos:** `bug` | `feature` | `task` | `epic` | `chore`

---

# Memoria persistente y aprendizajes

**Principio:** los aprendizajes valiosos sobreviven entre sesiones. Antes de empezar una tarea conocida, buscar contexto previo; al terminar, persistir lo no obvio.

## Cuándo persistir
- Decisión arquitectónica con trade-offs
- Bug arreglado con root cause no obvio
- Convención o patrón nuevo establecido
- Preferencia o restricción del usuario aprendida
- Gotcha o edge case descubierto
- Confirmación o rechazo del usuario sobre un approach

## Cuándo NO persistir
- Patrones derivables del código actual (la fuente es el código)
- Git history o quién cambió qué (la fuente es `git log`)
- Detalles de tarea en curso (eso vive en la conversación)
- Info ya documentada en CLAUDE.md/AGENTS.md/vault

## Mecanismos disponibles (en orden de preferencia)
1. **Engram MCP** — si está configurado en el CLI (ver `.local.md` para protocolo y tools).
2. **Memoria interna del CLI** — si el CLI tiene mecanismo nativo file-based (cada uno tiene el suyo; ver `.local.md`).
3. **Vault** — fallback siempre disponible: markdown en `~/Code/_vault` siguiendo la convención.

---

# Cierre de sesión

Una sesión no termina hasta que `git push` sea exitoso. Workflow obligatorio:

1. Crear issues para trabajo de seguimiento
2. Correr quality gates si hubo cambios de código (tests, linters, build)
3. Actualizar estado de issues (cerrar terminados, actualizar en progreso)
4. **Push obligatorio:**
   ```bash
   git pull --rebase
   bd sync          # solo si el repo usa beads (.beads/ presente)
   git push
   git status       # debe mostrar "up to date with origin"
   ```
5. Limpiar stashes y branches remotos sin uso
6. Verificar: todo commiteado Y pusheado
7. Resumen de contexto para la próxima sesión

Si el push falla, resolver y reintentar — no dejarlo a medias.

---

# Linear (aplica si MCP disponible)

- **Linear** — sistema oficial Apprecio para issue tracking. Workspace: `https://linear.app/apprecio-producto`. Dividido en 4 teams: `RYR` (R&R / Fuerza / SL / Engagement), `App` (mobile), `Platform` (infra / core / soporte), `Product Planning` (discovery, shaping). Es el canal principal de comunicación laboral en línea — cada comentario es comunicación, no solo metadata.

Para IDs específicos (teams, states, labels) y referencia de tools: `~/Code/_vault/_work/apprecio/_shared/linear-config.md`. Alternativa: usar tools nativos del MCP de Linear (`list_teams`, `list_issue_statuses`, `list_issue_labels`, etc.) para datos frescos.

## Antes de publicar comentario en Linear (`mcp__linear__save_comment`)
Verificar siempre:
1. **¿Es reply?** Si responde a alguien, DEBE tener `parentId`. Sin parent fragmenta hilos.
2. **¿Tiene @mención?** Sin mención, el destinatario no recibe notificación.
3. **¿Tiene call to action?** Debe quedar claro qué se espera del destinatario.

Si falta alguno, advertir antes de publicar:
```
⚠️ Pre-Linear Comment:
  [ ] parentId: {presente/FALTA}
  [ ] @mención: {presente/FALTA}
¿Publicar así o corregir?
```

## Antes de crear issue en Linear (`mcp__linear__save_issue`, solo al crear)
Verificar:
1. **¿Puede ser hilo en un issue existente?** Regla de Ignacio: "no crear issues sin consultarme; si se resuelve en una sesión, va como hilo del issue existente".
2. **¿Tiene parentId si es subissue?**
3. **¿Tiene descripción con contexto?**

Si es standalone (sin parent), advertir:
```
⚠️ Pre-Linear Issue:
  Issue standalone (sin parent).
  ¿Consultaste con Ignacio? ¿Puede ser hilo en un issue existente?
¿Crear así o ajustar?
```

---

# Vault — cerebro único

**Path:** `~/Code/_vault` (markdown + frontmatter, repo privado git — git es el sync, no iCloud).

**Regla:** toda doc persistente, nota, decisión, aprendizaje o transcripción → vault. Nunca en `Code/work/*-project/docs/` (legacy de repo). README.md y ADRs técnicos cercanos al código sí permitidos en repos.

**Convención de directorios** (estructura interna libre por proyecto):
- `_personal/` — uso personal
- `_work/<org>/projects/<slug>/` — un dir por proyecto
- `_work/<org>/_shared/` — documentación cross-proyecto

**Frontmatter recomendado** (no obligatorio): `type`, `project`, `date`, `status`, `related_to: ["[[wikilink]]"]`.

**Filenames:** kebab-case sin tildes. Primer H1 del cuerpo = display title (no usar frontmatter `title`).

**Drive:** read-only. Solo `/prd` toca Drive (lee PRDs externos). Sharing manual con `gws-drive` ad-hoc cuando se pida.

**Acceso desde herramientas:**
- Lectura y escritura: cualquier CLI con permisos sobre `~/Code/_vault`.
- Si MCP de Obsidian disponible, preferirlo sobre escritura directa.
