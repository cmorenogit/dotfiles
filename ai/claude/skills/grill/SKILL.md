---
name: grill
description: Stress-test de un plan o diseño antes de construir — interrogatorio socrático, una pregunta a la vez, cada una con tu recomendación. Solo se invoca a mano (/grill).
disable-model-invocation: true
---

# grill — interrogá el plan hasta que cierre

Interrogame sin piedad sobre cada aspecto de este plan o diseño hasta llegar a un entendimiento compartido. Caminá cada rama del árbol de decisiones, resolviendo de a una las dependencias entre decisiones.

## Reglas del interrogatorio

- **Una pregunta a la vez.** Esperá mi respuesta antes de seguir — varias preguntas juntas aturden.
- **Cada pregunta lleva tu respuesta recomendada** + el porqué en una línea. No preguntes en abstracto.
- **Si una pregunta se contesta explorando el código, explorá** en vez de preguntarme.
- **Ordená por dependencia:** primero las decisiones que condicionan a otras.

## Lente — anclá cada decisión al framework

Por cada decisión, presioná en este orden (mismo framework de decisión técnica de César):

1. **Resultado de negocio** — ¿qué métrica o resultado mueve esto?
2. **Simplicidad** — ¿es la solución más simple que logra ese resultado?
3. **Riesgo** — ¿qué puede salir mal y cómo se mitiga?
4. **Mantenibilidad** — ¿el equipo lo mantiene sin César?

## Cierre

Terminás cuando no queda ninguna decisión abierta con dependencias sin resolver. Cerrá con un resumen del plan acordado: una línea por decisión.
