---
name: handoff
description: >
  Crea un documento temporal de traspaso para continuar el trabajo en otra sesión o agente sin
  arrastrar tokens. Úsalo desde Pi para bifurcar contexto, abrir una sesión limpia, delegar a otro
  agente o salir de una conversación saturada. Genera markdown descartable en /tmp, con punteros
  en vez de copias y secretos redactados.
argument-hint: "<foco de la próxima sesión>"
---

# handoff — traspaso de contexto entre sesiones en Pi

Empaqueta lo esencial de la sesión actual en un markdown para que otra sesión/agente continúe desde ahí.
El documento es un **relevo de turno descartable**, no documentación permanente.

## Cuándo usarlo

| Caso | Usar |
|---|---|
| Continuar el mismo hilo con menos ruido | compact / resumen en la misma sesión |
| Abrir otra sesión limpia con un objetivo puntual | handoff |
| Bifurcar una tarea fuera de scope | handoff |
| Delegar ida/vuelta a otro agente humano o CLI | handoff |

Regla mental: compact = *seguir*; handoff = *bifurcar*.

## Invocación en Pi

Usar:

```text
/skill:handoff <foco de la próxima sesión>
```

También aplica si César lo pide en lenguaje natural: “hacé un handoff para <foco>”.

En Pi, los argumentos del skill command pueden llegar como texto del usuario después de cargar el skill. Tratá ese texto como el **foco de la sesión destino**.

Si no hay foco claro, preguntá una sola cosa: **“¿En qué se concentra la sesión nueva?”**
No generes un handoff con objetivo difuso.

## Pasos

1. **Fijar destino.** Confirmá en una línea el objetivo de la sesión nueva.
2. **Recolectar solo el slice relevante para ese objetivo:**
   - Objetivo y por qué importa.
   - Estado actual / dónde se quedó el trabajo.
   - Decisiones ya tomadas y razón — para no re-litigar.
   - Archivos/áreas como **punteros**: `ruta/archivo.ext:línea`, issue Linear, PR#, commit, URL.
   - Próximos pasos concretos.
   - Blockers / callejones sin salida — para no repetirlos.
   - Suggested skills/tools: qué skills o herramientas debería invocar la próxima sesión.
3. **Higiene obligatoria:**
   - **Punteros > copias.** Si algo vive en un archivo, issue o PR, enlazalo; no lo dupliques.
   - **Redactar secretos:** API keys, tokens, passwords, PII → `[REDACTED]`.
   - Proporcional: tarea chica = handoff corto.
4. **Escribir en `/tmp`:**
   ```bash
   FECHA=$(date +%F)
   SLUG=<kebab-case-del-foco>
   OUT="/tmp/handoff-${SLUG}-${FECHA}.md"
   ```
   Path esperado: `/tmp/handoff-<slug>-<YYYY-MM-DD>.md`. La fecha sale de `date +%F`, no se infiere.
5. **Cerrar con:**
   - Path del archivo.
   - Prompt para abrir la sesión nueva.

## Template del documento

```markdown
# Handoff — <foco de la sesión destino>

> Generado: <YYYY-MM-DD> · Origen: <proyecto / issue si aplica> · Descartable (no es documentación)

## Objetivo de esta sesión
<qué tiene que lograr la sesión nueva, en 1-2 líneas>

## Contexto clave
<lo mínimo para entender el punto de partida>

## Decisiones ya tomadas
- <decisión> — <por qué> (no re-litigar)

## Archivos y referencias (punteros, no copiar)
- `ruta/archivo.ext:línea` — <qué hay ahí>
- Linear <ID> / PR #<n> / commit <hash> / URL — <qué es>

## Próximos pasos
1. <paso concreto>

## Blockers / callejones sin salida
- <lo que NO funcionó, para no repetirlo>

## Suggested skills/tools
- `<skill o herramienta>` — <para qué sirve acá>

## Sensibles
- Sin secretos en este archivo (redactados con [REDACTED]).
```

## Respuesta final al usuario

Devolvé algo equivalente a:

```text
Handoff creado: /tmp/handoff-<slug>-<YYYY-MM-DD>.md

En la sesión nueva pegá:
Leé /tmp/handoff-<slug>-<YYYY-MM-DD>.md y continuá con <foco>.
```

No incluyas `pi --name ...` en la respuesta principal. Si César pide explícitamente un comando de terminal,
podés darlo como alternativa opcional, pero el default es solo el prompt para pegar en la sesión nueva.

## Integración con el mundo de César

- Trabajo con issue de Linear → en “Archivos y referencias” enlazá el issue (`RYR-XXX`, `APP-XXX`, etc.) y PRs;
  no copies el hilo.
- El `.md` vive en `/tmp`, **no** en el vault. Si hace falta dejar rastro, guardá solo un link o mención en la
  carpeta del issue, nunca el handoff entero.
- El documento resultante es markdown plano y puede ser leído por Pi, Claude Code, Codex, Copilot CLI u otro agente.

## Reglas duras

- El handoff es **descartable**.
- **Nunca** secretos en texto plano.
- **Punteros > copias**.
- Si el objetivo no está claro, preguntá antes de escribir.
