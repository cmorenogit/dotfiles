---
name: second-opinion
description: Peer review cross-model — pedile a Pi (GPT vía CLI, un modelo distinto a Claude) una segunda opinión sobre CUALQUIER artefacto en curso — un plan, un análisis, un comentario, una decisión, un diff. Claude arma un paquete de contexto auto-suficiente (Pi es ciego — no lee código, repo ni conversación), consulta a Pi en modo no interactivo read-only, y contrasta cada objeción con posición propia (acepta/rechaza con argumento). Solo cuando César lo pide. Triggers — "/second-opinion", "segunda opinión de esto", "peer review con pi", "qué opina pi", "pedile a pi que lo revise".
---

# second-opinion — peer review con otro modelo

Pi corre GPT (default `openai-codex/gpt-5.6-sol`, thinking high) — un modelo distinto a Claude. El valor es la diversidad: ver lo que este modelo/contexto no vio. La crítica es **insumo, no veredicto** — César decide qué se aplica.

## Objeto

Lo que César señale; si no señala nada, el último artefacto sustancial de la conversación (plan, análisis, comentario borrador, decisión, diff). Si es ambiguo, confirmá en una línea qué va a revisión antes de armar el paquete.

## Paso 1 — Paquete auto-suficiente

**Pi es ciego**: sin tools, sin repo, sin Linear, sin esta conversación. Todo lo que necesite para juzgar va EN el paquete — código citado (no rutas), decisiones previas con su porqué, restricciones. Regla de tamaño: todo lo que necesita, nada de lo que no — nunca volcar la conversación entera.

Escribí `/tmp/second-opinion-<slug>.md`:

```markdown
# Encargo
Sos un peer reviewer adversarial. Tu trabajo es encontrar lo que el autor no vio — NO validar ni elogiar. Anclá cada objeción a: resultado de negocio · simplicidad · riesgo · mantenibilidad.

## Preguntas específicas
<3–5 preguntas a medida del objeto: cuál es el supuesto más frágil, qué alternativa no se consideró, dónde falla esto>

# Objeto bajo revisión
<verbatim>

# Contexto (todo lo que necesitás está acá — no podés leer nada más)
- Situación: <qué se está haciendo y en qué etapa>
- Decisiones ya cerradas (cuestionalas solo con razón fuerte): <decisión → porqué>
- Restricciones: <técnicas, de negocio, de equipo>
- Código/datos relevantes: <extractos pegados>

# Formato de salida
Objeciones numeradas, cada una: severidad (alta/media/baja) · qué está mal o falta · qué cambiarías concretamente. No menciones lo que está bien. Cerrá con: "lo más importante que el autor no vio".
```

**Redactá secretos** antes de escribir: keys, tokens, credenciales, datos personales. El paquete sale de la máquina hacia el provider del modelo.

## Paso 2 — Invocación

```bash
timeout 300 pi -p --no-tools --no-session --no-extensions --no-skills --no-context-files \
  @/tmp/second-opinion-<slug>.md </dev/null
```

- `</dev/null` **obligatorio** — sin TTY, pi cuelga esperando stdin.
- Sin `--model` → usa el default de la suscripción. Si César pide otro modelo: `--provider openrouter --model <x>` (auth ya configurada: `openai-codex`, `openrouter`, `minimax`).
- El thinking high default tarda; si excede el timeout, correr en background y avisar.
- Si exit ≠ 0 u output vacío → reportá el error verbatim. NUNCA inventes la review.

## Paso 3 — Contraste, no obediencia

Tomá posición por cada objeción:

| # | Objeción de Pi | Posición | Porqué |
|---|---|---|---|

- **Acepto** → ajuste concreto propuesto.
- **Rechazo** → argumento con evidencia.
- **La decide César** → cuando es scope/producto o empate técnico real.

Anti-patrones: **revisor-oráculo** (plegarse a todo lo que diga el otro modelo — defendé con evidencia) · **teatro** (correr esto después de cerrar la decisión solo para confirmarla — se corre ANTES de cerrar).

## Paso 4 — Entrega

A César: (1) qué cambió la segunda opinión, en una línea; (2) la tabla de contraste; (3) ruta del paquete y del output completo por si quiere el verbatim. César decide qué se aplica.
