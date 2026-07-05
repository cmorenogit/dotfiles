---
name: lavish
description: Convierte una respuesta compleja o visual en un artefacto HTML rico que ves y anotás en el navegador, devolviendo tu feedback al agente — vía el CLI lavish-axi, con telemetría apagada. Úsalo cuando estás por dar un plan, comparación, diagrama, tabla, diff de código, reporte o cualquier cosa más fácil de captar en visual que en prosa. Triggers — "/lavish <qué mostrar>", "mostrame esto en HTML", "visualizá esto", "pasá esto a HTML", "quiero verlo en el navegador".
---

# lavish — ver y anotar en HTML

Toma lo que estás por responder (o lo que el usuario pida) y lo entrega como **HTML interactivo** que César revisa en el navegador, anota (elementos o rangos de texto) y devuelve como feedback al agente. Reemplaza el loop pobre de "screenshot + describir qué cambiar".

Corre sobre `lavish-axi` (auditado 2026-06-24, v0.1.31: seguro, server local en loopback `127.0.0.1`, sin exfiltración de paths ni contenido).

## Reglas fijas de este skill (no negociar)

1. **Telemetría OFF siempre** — prefijá TODA invocación con `LAVISH_AXI_TELEMETRY=0`. La herramienta hace un ping Umami anónimo por default; acá no.
2. **Nunca** corras `lavish-axi setup hooks` — modifica la config de los agentes (Claude Code/Codex/OpenCode).
3. **HTML efímero** — creá el artefacto en el **directorio scratchpad de la sesión** (el que el harness indica para temporales), NO dentro de un repo ni del vault. Solo persistilo en otro lado si el usuario lo pide explícitamente (ej. para un PR o Linear).

## Flujo

1. **Generá el HTML** auto-contenido siguiendo el design system de abajo. Default de nombre: `<scratchpad>/lavish/<nombre>.html`.
2. **Abrí la sesión:** `LAVISH_AXI_TELEMETRY=0 npx -y lavish-axi <file>.html`
   Arranca el server local y abre el navegador. Usá `--no-open` para asegurar la sesión sin abrir otra ventana.
3. **Esperá feedback en background:** `LAVISH_AXI_TELEMETRY=0 npx -y lavish-axi poll <file>.html`
   Long-pollea en **silencio** hasta que el usuario anota/envía o cierra la sesión — corrélo como tarea en background y **no lo mates**. Si lo matan o expira, re-corrélo: el feedback encolado nunca se pierde.
4. **Aplicá y respondé:** tras aplicar el feedback, volvé a pollear con `--agent-reply "<mensaje>"` para mostrar tu respuesta en el navegador y seguir el loop.
5. **Cerrá:** `LAVISH_AXI_TELEMETRY=0 npx -y lavish-axi end <file>.html` cuando la revisión terminó. `... stop` apaga el server (igual se auto-apaga al quedar idle).

## Design system (orden estricto; parar en el primero que aplique, y decir cuál usaste)

1. Si el usuario pidió un look o nombró un design system → ese.
2. Si no → inspeccioná el **proyecto del que trata** el artefacto (puede no ser el cwd): su config de Tailwind/tema, CSS vars o tokens, librería de componentes, assets de marca, páginas ya estiladas. Si el artefacto mockea la UI de una app de Apprecio, renderizá en SU design system para que sea fiel.
3. Solo si ambos vienen vacíos → `LAVISH_AXI_TELEMETRY=0 npx -y lavish-axi design` para el fallback CDN (Tailwind CSS v4 browser + DaisyUI v5, tema `luxury`). Ojo: no uses `@apply` de DaisyUI dentro de bloques `<style>` del runtime browser de Tailwind.

## Reglas de HTML

- **Portable:** lavish no inyecta ningún design system; el HTML se ve igual abierto directo en un navegador. Manténlo así.
- **Assets locales** (img/css/fonts/scripts): copialos junto al HTML y referencialos con rutas **relativas**. Nunca con `/` adelante — las rutas root no resuelven. Si necesitás assets de un repo, creá el HTML en una carpeta junto a ellos en vez del scratchpad.
- **Sin overflow horizontal:** layouts angostos a propósito, `minmax(0, 1fr)` y `min-width: 0` en hijos de grid/flex, y wrap/truncate de labels largos.
- **Controles nativos** (inputs, checkboxes, radios, selects, contenteditable) ya son interactivos sin marcado extra. Para recoger decisiones/triage del usuario dentro del artefacto, leé `playbook input`.

## Playbooks

`LAVISH_AXI_TELEMETRY=0 npx -y lavish-axi playbook <id>` para guía enfocada: `diagram`, `table`, `comparison`, `plan`, `code`, `input`, `slides`. Un artefacto suele combinar varios (un plan con comparación + diagrama) — leé todos los relevantes.

## Notas

- Si algún día instalás el skill oficial (`npx skills add kunchenguid/lavish-axi --skill lavish`), colisiona con este nombre — quedate con uno.
- `LAVISH_AXI_HOST` bindea más allá de loopback (expone un server sin auth que sirve archivos locales). No lo toques salvo red de confianza explícita.
