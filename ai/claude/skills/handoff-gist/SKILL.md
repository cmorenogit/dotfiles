---
name: handoff-gist
description: >
  Variante CROSS-MACHINE de /handoff: comprime el contexto de la sesión ACTUAL en un documento de
  traspaso y lo publica como gist SECRETO de GitHub, para que otra sesión en OTRA máquina
  (mac mini ↔ local) lo consuma con un comando — sin depender de /tmp (local a cada máquina) ni
  del vault (reservado para documentación persistente). Devuelve la URL del gist (revisable desde
  cualquier dispositivo) + el texto listo para pegar en la sesión destino, que lee el gist y lo
  borra al consumirlo. Triggers: "/handoff-gist", "handoff a la otra máquina", "pasá esto a mi
  sesión local/remota", "handoff cross-machine", "handoff remoto".
---

# handoff-gist — traspaso de contexto entre máquinas

Wrapper fino sobre `/handoff`: **misma compresión, distinto transporte**. `/handoff` escribe en
`/tmp` y solo sirve para otra sesión en la misma máquina; este publica un **gist secreto** que
cualquier sesión de César con `gh` autenticado puede leer. El documento sigue siendo un **relevo
de turno: descartable** — el ciclo de vida termina cuando la sesión destino lo consume y borra el
gist. Nunca va al vault: transporte ≠ documentación.

## Cuándo usar cuál

| | Transporte | Alcance |
|---|---|---|
| `/handoff` | `/tmp` | otra sesión en ESTA máquina |
| `/handoff-gist` | gist secreto de GitHub | otra sesión en OTRA máquina |

## Postura de riesgo (aceptada por César, 2026-07-16)

Un gist "secret" no aparece listado públicamente, pero **cualquiera con la URL lo lee sin auth**.
Tolerable porque: (a) el contenido típico es personal, no laboral; (b) la higiene de `/handoff`
redacta secretos y enlaza en vez de copiar; (c) el gist se borra al consumirse (ventana de
exposición corta). **Guarda:** si el slice contiene información laboral sensible más allá de
punteros (más que IDs de issue o paths de archivo), avisar a César antes de publicar y ofrecer el
fallback `/handoff` + fetch por SSH.

## Pasos

1. **Compresión — idéntica a `/handoff`.** Leé `~/.claude/skills/handoff/SKILL.md` y aplicá sus
   pasos 1 a 3 y su template tal cual (fijar el foco desde `$ARGUMENTS`, recolectar el slice
   relevante, higiene obligatoria: no duplicar, redactar secretos). No dupliques esa lógica acá —
   la fuente es ese archivo.

2. **Escribir y publicar:**
   ```bash
   FECHA=$(date +%F)
   SLUG=<kebab-case-del-foco>
   OUT="/tmp/handoff-${SLUG}-${FECHA}.md"
   # ...escribir el doc con el template de /handoff...
   gh gist create "$OUT" --desc "handoff: <foco> (${FECHA})"
   ```
   `gh gist create` es secreto por default — **NUNCA pasar `--public`**. Capturar la URL que
   imprime; el ID del gist es su último segmento.

3. **Barrido de huérfanos:** revisar si quedaron handoffs viejos sin consumir:
   ```bash
   gh gist list --limit 30 | grep -i "handoff:" || true
   ```
   Si hay gists `handoff:` de corridas anteriores, listárselos a César y ofrecer
   `gh gist delete <id>` — **nunca borrarlos sin confirmación** (podrían estar pendientes de
   consumo).

4. **Cerrar.** Devolver a César dos cosas:
   - **URL del gist** — para revisar el contenido desde cualquier dispositivo antes de abrir la
     sesión destino.
   - **Texto de arranque** para pegar en la sesión destino (determinista, sin búsqueda):
     > Corré `gh gist view <ID> --raw`, cargá ese contexto y continuá con \<foco\>.
     > Al confirmar que cargaste el contexto: `gh gist delete <ID>` (handoff consumido).

## Requisitos

`gh` autenticado con scope `gist` en AMBAS máquinas — verificar con `gh auth status`; si falta el
scope: `gh auth refresh -s gist`.
