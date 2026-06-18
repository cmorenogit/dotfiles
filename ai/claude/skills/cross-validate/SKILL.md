---
name: cross-validate
description: >
  Segunda opinión de un modelo de OTRO linaje (GPT-5.5 vía `pi`) para validar una decisión,
  propuesta, análisis, hallazgo, PR o priorización. Un evaluador de otra familia atrapa los puntos
  ciegos que un solo linaje normaliza. Corre el evaluador externo de forma fiable, lo reconcilia con
  el juicio de Claude (fail-closed) y reporta — NUNCA decide ni postea por vos. Triggers:
  "/cross-validate", "validá esto con un segundo modelo", "segunda opinión de GPT", "que lo revise
  otro modelo", "pedile a pi", "doble check cross-model", "evaluá esto con otro modelo".
---

# cross-validate — segunda opinión cross-model (GPT-5.5 vía `pi`)

Principio rector: **el valor está en el linaje distinto, no en la mecánica.** Dos modelos de la misma familia comparten puntos ciegos — normalizan los mismos errores. Un modelo de otra familia (GPT vs Claude) marca lo que el primero deja pasar. Este skill convierte ese "doble check cross-model" en algo barato y repetible. **Produce un veredicto; César decide.**

Generaliza el "Evaluador B vía pi" del skill `linkedin-post` para cualquier objeto evaluable, y **es la fuente de verdad del patrón `pi`** — el comando aquí está verificado (ver "Regla de oro").

## Cuándo usarlo · cuándo no

| Usalo para | No lo uses para |
|---|---|
| Validar una **decisión** técnica/de producto con trade-offs | Tareas mecánicas sin juicio (formatear, renombrar) |
| Stress-test de una **propuesta** antes de comprometerla | Cuando ya hay consenso y el costo de equivocarse es bajo |
| Confirmar un **hallazgo** / root-cause no obvio | Generar contenido (para eso está el evaluador de cada skill) |
| Segunda lente sobre un **análisis, PR o priorización** | Reemplazar el criterio de César o de Ignacio |

Es **advisory**: agrega una voz independiente. No es un gate de despliegue.

## Input

`/cross-validate <objeto a evaluar>` — texto inline, ruta a un archivo/nota del vault, un issue/PR, o una decisión descrita en la conversación. Opcional: la **rúbrica** (qué cuenta como falla). Si no se da rúbrica, derivá los 3-5 bloqueantes del dominio del objeto.

## Flujo

### 0 · Encuadrar (antes de invocar a nadie)

- **Qué se evalúa**, en 1-2 líneas. Si es una ruta/issue, leelo primero.
- **Rúbrica = los bloqueantes**, 3-5 checks concretos y verificables (no "¿está bien?"). Ej: consistencia de datos, edge case X, riesgo de seguridad, coherencia outcome↔output.
- **Acotar.** Pasá al evaluador SOLO el objeto + la rúbrica, no la historia de cómo se construyó (eso sesga). Resumí inputs largos a lo esencial.

### 1 · Evaluador externo — GPT-5.5 vía `pi`

Construí UN prompt con esta estructura y pasáselo al helper:

```
<rol en 1 línea: "Eres evaluador {técnico|de producto} independiente y escéptico.">
<rúbrica: los bloqueantes como checks cortos, uno por línea>
<el objeto a evaluar, acotado>
<formato de salida EXACTO: "Responde SOLO: VEREDICTO=APRUEBA|AJUSTES|RECHAZA, y por cada
 falla una línea (máx N líneas)." >
```

Invocación (el helper resuelve todos los gotchas — flags, timeout, parser, reintento):

```bash
~/.claude/skills/cross-validate/pi-eval.sh "<el prompt de arriba, como un solo argumento>"
```

- Imprime SOLO la respuesta del modelo en stdout. Exit `0` ok · `1` sin respuesta (timeout) · `2` `pi` no instalado.
- Si exit `1`: el prompt seguramente invitó a razonar. **Acortá el input y endurecé el formato de salida** (menos líneas, veredicto primero) y reintentá una vez. Si vuelve a fallar, reportá a César que el evaluador externo no respondió — **no bloquees la decisión por eso**, seguí con el juicio de Claude solo y decilo explícito.
- Para inputs grandes podés subir el timeout: `PI_EVAL_TIMEOUT=180 ~/.claude/.../pi-eval.sh "..."`.

### 2 · Evaluador interno — Claude

- **Modo liviano (default).** Tu propio juicio (el del agente principal) contra la **misma** rúbrica. Sirve cuando el objeto ya pasó por vos.
- **Modo riguroso (decisiones de alto impacto / irreversibles).** Lanzá un sub-agente Claude **fresco** (tool `Agent`) que reciba SOLO el objeto + la rúbrica, sin ver cómo se construyó — evita que Claude apruebe su propio trabajo. Igual que el doble gate de `linkedin-post`.

Elegí el modo por el costo de equivocarse, no por comodidad.

### 3 · Reconciliar (fail-closed)

| Caso | Acción |
|---|---|
| Ambos **APRUEBA**, sin bloqueantes | Veredicto: aprueba. Reportá que coincidieron. |
| Cualquiera marca un **bloqueante** | Veredicto: no aprueba. El bloqueante manda. |
| **Discrepan** | La discrepancia **es la señal** — ahí suele estar el punto ciego. Investigá *por qué* difieren; ante la duda aplicá el criterio **más estricto**, nunca el más indulgente. |

Nunca promedies veredictos ni elijas el más cómodo. El delta entre los dos modelos es el producto más valioso de este skill — explícalo.

### 4 · Output a César

Tabla compacta + recomendación. No el volcado crudo de cada evaluador.

```
| Evaluador        | Veredicto | Bloqueantes señalados |
|------------------|-----------|-----------------------|
| GPT-5.5 (pi)     | …         | …                     |
| Claude           | …         | …                     |

**Reconciliación:** <coinciden / discrepan en X> → **recomendación accionable**.
**Punto ciego detectado por el cross-model:** <lo que un linaje vio y el otro no, si aplica>.
```

## Regla de oro del prompt (VERIFICADO — lo que hace que esto funcione)

`gpt-5.5-codex` (el modelo por suscripción ChatGPT que usa `pi`) **razona proporcional a cuánto lo invita el prompt**. Sin freno explícito, una evaluación cuelga >120s y `timeout` la mata con salida vacía. Con freno, responde en **5-41s**. El helper antepone el freno por defecto, pero igual:

1. **Pedí "juicio inmediato, sin razonar paso a paso".** Es la variable causal #1 (no el largo del prompt, como se creía antes).
2. **Forzá un formato de salida acotado** — veredicto + N líneas. Respuesta corta = menos generación = más rápido y más útil.
3. **Pocas opciones, objeto resumido.** Si tenés que evaluar N candidatos, hacelo en tandas chicas, no todos de una.
4. El output JSON está **buffereado**: el archivo queda vacío hasta que el proceso termina. No midas progreso por bytes — el helper ya lo maneja.

## Comando subyacente (referencia — usar el helper salvo depuración)

```bash
PI_OFFLINE=1 PI_SKIP_VERSION_CHECK=1 timeout 120 \
  pi -p --no-tools --no-session -nc -ne -ns --thinking off --mode json "<PROMPT>"
```

Reglas duras (cada una verificada fallando):

- **NO** pasar `--provider openai` ni `--model …` → exigen una API key inexistente y **cuelgan/fallan**. Sin ellos, `pi` usa el default del usuario: provider `openai-codex` / modelo `gpt-5.5` por **OAuth de ChatGPT**.
- **SIEMPRE** `PI_OFFLINE=1 PI_SKIP_VERSION_CHECK=1` → evitan el chequeo de versión por red que cuelga al arrancar (no bloquean la llamada al LLM).
- Verificar que respondió GPT, no otro modelo: en el JSON, `message.model == "gpt-5.5"`.
- Modelos disponibles por suscripción: `pi --list-models` → `openai-codex` tiene `gpt-5.5`, `gpt-5.4`.

## Guardrails

- **Advisory, no autoridad.** Reporta y recomienda; César (técnica) e Ignacio (producto) deciden. NUNCA postea, comenta ni despliega.
- **Fail-closed.** Ante discrepancia o cualquier bloqueante, no apruebes. No bajes el umbral para forzar un pase.
- **Independencia real.** El evaluador externo y el interno-fresco reciben el objeto + la rúbrica, nunca cómo se construyó.
- **El cross-model no respondió ≠ aprobado.** Si `pi` falla tras el reintento, seguí con el juicio de Claude pero **declaralo**; no presentes una sola voz como si fueran dos.
- **Sin secretos al evaluador externo.** `pi` manda el prompt a la API de OpenAI (suscripción de César). No le pases credenciales, tokens, PII ni datos sensibles de clientes — resumí/redactá antes.
