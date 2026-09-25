---
name: handoff
description: >
  Comprime el contexto de la sesión ACTUAL en un documento de traspaso (.md) para arrancar OTRA
  sesión limpia que continúe sin arrastrar tokens. Es branching de contexto (bifurcar), no
  compresión en sitio — a diferencia de /compact, que sigue en la misma sesión. Guarda el documento
  en /tmp (es descartable), enlaza en vez de duplicar, y redacta secretos. Útil cuando aparece una
  tarea fuera de scope, cuando la sesión entró en la "zona tonta" (~120k tokens), o para un
  sub-agente manual (handoff de ida y vuelta). Triggers: "/handoff", "hacé un handoff", "pasá esto a
  otra sesión", "documento de traspaso", "bifurcá esta tarea", "necesito una sesión limpia para <X>".
---

# handoff — traspaso de contexto entre sesiones

Empaqueta lo esencial de ESTA sesión en un markdown para que OTRA sesión nueva continúe desde ahí,
sin heredar el ruido acumulado. El documento es un **relevo de turno: descartable**, no documentación.

## handoff vs compact (no confundir)

| | Qué hace | Cuándo |
|---|---|---|
| `/compact` | comprime y **sigue en la misma** sesión | querés mantener el hilo (ej. un debug largo) |
| `/handoff` | extrae el slice relevante → **sesión nueva** | apareció algo aparte, o la actual ya está cargada |

Regla mental: compact = *seguir*; handoff = *bifurcar*.

## Input

`$ARGUMENTS` = el **foco de la sesión destino** (qué va a hacer la próxima sesión). Es lo que define
qué es señal y qué es ruido.

- Si no se especificó el foco, **preguntar una sola cosa**: "¿En qué se concentra la sesión nueva?"
- No arrancar el handoff con un foco difuso — sin objetivo, el documento no sabe qué incluir/omitir.

## Pasos

1. **Fijar el destino.** Confirmá en una línea el objetivo de la sesión nueva (de `$ARGUMENTS`).
2. **Recolectar el slice relevante SOLO para ese objetivo** (no toda la sesión):
   - Objetivo y por qué importa.
   - Estado actual / dónde se quedó el trabajo.
   - Decisiones ya tomadas, con su razón — para que la sesión nueva no las re-litigue.
   - Archivos/áreas como **punteros**: `ruta/archivo.ext:línea`, issue Linear, PR#, commit — NO el contenido.
   - Próximos pasos concretos.
   - Blockers / lo que NO funcionó — para que no repita callejones sin salida.
   - **Suggested skills**: qué skills debería invocar la próxima sesión (ej. `/sdd-apply`, `/pr-review`,
     `/linear-respond`, `supabase`). El próximo agente trabaja mejor si sabe qué herramientas tiene a mano.
3. **Higiene obligatoria:**
   - **No duplicar**: si algo vive en un archivo, issue o PR, enlazá — no lo copies.
   - **Redactar secretos**: API keys, tokens, passwords, PII → nunca en el `.md`. Reemplazar por `[REDACTED]`.
   - Proporcional: tarea chica = handoff corto.
4. **Escribir el documento** en el directorio temporal (es descartable):
   ```bash
   FECHA=$(date +%F)
   SLUG=<kebab-case-del-foco>
   OUT="/tmp/handoff-${SLUG}-${FECHA}.md"
   ```
   Path final: `/tmp/handoff-<slug>-<YYYY-MM-DD>.md`. La fecha sale de `date +%F` del sistema, no inferida.
5. **Cerrar.** Devolvé a César (a) el path del archivo y (b) el one-liner para arrancar la sesión nueva:
   > Abrí una sesión nueva y pegá: «Leé `/tmp/handoff-<...>.md` y continuá con <foco>».

## Template del documento de handoff

```markdown
# Handoff — <foco de la sesión destino>

> Generado: <YYYY-MM-DD> · Origen: <proyecto / issue si aplica> · Descartable (no es documentación)

## Objetivo de esta sesión
<qué tiene que lograr la sesión nueva, en 1-2 líneas>

## Contexto clave
<lo mínimo para entender el punto de partida — sin tener que releer la sesión origen>

## Decisiones ya tomadas
- <decisión> — <por qué> (no re-litigar)

## Archivos y referencias (punteros, no copiar)
- `ruta/archivo.ext:línea` — <qué hay ahí>
- Linear <ID> / PR #<n> / commit <hash> — <qué es>

## Próximos pasos
1. <paso concreto>

## Blockers / callejones sin salida
- <lo que NO funcionó, para no repetirlo>

## Suggested skills
- `/<skill>` — <para qué sirve acá>

## Sensibles
- Sin secretos en este archivo (redactados con [REDACTED]).
```

## Integración con el mundo de César

- **Trabajo de un issue de Linear** → en "Archivos y referencias" enlazá el issue (`RYR-XXX`) y los PRs;
  no copies el hilo. El `.md` vive en `/tmp`, **no** en el vault (es descartable). Si querés dejar rastro,
  guardá solo un *link* en la carpeta del issue (`projects/<slug>/issues/<ID>/`), nunca el handoff entero.
- **Sin vendor lock-in**: es markdown plano. Sirve igual para otra sesión de Claude Code, Codex o Copilot CLI.

## Reglas duras

- El documento es **descartable** — no lo guardes en un repo como si fuera doc permanente.
- **NUNCA** secretos en texto plano.
- **Punteros > copias.** Si la sesión nueva necesita el detalle, que abra el archivo/issue/PR.
