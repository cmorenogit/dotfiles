---
name: grill
description: Stress-test de un plan, decisión o diseño antes de construir — interrogatorio por rondas sobre el árbol de decisiones, cada pregunta con tu recomendación anclada al marco de César (negocio · simplicidad · riesgo · mantenibilidad). Lo invoca César (/grill) o el agente en la fase de plan de un issue, antes del OK del plan. Nunca desde un subagente: necesita a César para responder.
---

# grill — interrogá el plan hasta que cierre

Basado en `grilling` de Matt Pocock (mattpocock/skills, versión de ago-2026: rondas por frontera), con el marco de decisión de César como lente.

Interrogá a César sin piedad hasta llegar a un entendimiento compartido. Modelá el tema como un **árbol de decisiones**: cada decisión abre las decisiones que dependen de ella.

## Rondas por frontera

La **frontera** es cada decisión cuyos prerrequisitos ya están resueltos: las preguntas que se pueden hacer *ahora* sin adivinar respuestas que todavía no escuchaste.

- Cada ronda pregunta **toda la frontera**, numerada, y después **esperás** las respuestas.
- Dos preguntas nunca comparten ronda si una depende de la otra: la dependiente va a una ronda posterior.
- Cada respuesta cambia el árbol: recalculá la frontera y armá la ronda siguiente (no la tenías escrita de antes).

Formato de cada pregunta (separadas por una línea horizontal):

```
❓ **Q1** - **<título>**: <la pregunta; puede tener varias opciones>

➡️ <tu respuesta recomendada> — <por qué, en una línea, citando el criterio que la decide>

---

❓ **Q2** - …
```

## Lente — anclá cada recomendación al marco de César

Por cada decisión, evaluá en este orden y citá el criterio que decide:

1. **Resultado de negocio** — ¿qué métrica o resultado mueve esto?
2. **Simplicidad** — ¿es la solución más simple que logra ese resultado?
3. **Riesgo** — ¿qué puede salir mal y cómo se mitiga?
4. **Mantenibilidad** — ¿el equipo lo mantiene sin César?

## Hechos vs decisiones

- **Los hechos son tu trabajo, nunca de César.** Si una pregunta necesita un dato del entorno (código, BD, Linear, un PR), buscalo: con un subagente si lleva tiempo. No bloquees la ronda: solo esperan las preguntas que dependen de esa búsqueda; el resto de la frontera se pregunta ya.
- **Las decisiones son de César.** Nunca te respondas una decisión a vos mismo: eso rompe el skill, aunque el contexto (un issue a resolver) parezca empujar a avanzar.
- Decisiones de producto (scope, prioridad, qué se entrega) se marcan como tales: el dueño puede ser Javier/Ignacio, no César; decilo en la pregunta.

## Cierre

La sesión termina cuando la frontera queda vacía: cada rama visitada, nada asumido en silencio. Cerrá con un resumen del plan acordado (una línea por decisión, con su criterio) y **no actúes** hasta que César confirme que el entendimiento es compartido.
