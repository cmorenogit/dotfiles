---
name: lane
description: Encuadra una revisión o respuesta en el lane de César (stopper técnico) — qué le toca decidir y qué es de Ignacio (merge), Julieth (QA) o Nicole (scope), más los criterios técnicos y anti-patrones que debe aplicar. Úsalo antes de emitir un veredicto técnico, o cuando una respuesta roza scope/QA/merge o una decisión de producto. Carga _shared/lane.md.
---

# lane — encuadre del rol

Recuerda los límites de César y las reglas de su rol técnico, para no invadir otro lane ni repetir un error conocido.

## Flujo

1. **Cargá el conocimiento:** `~/Code/_vault/_work/apprecio/_shared/lane.md` (canónico; engram `lane` como cache).
2. **¿Es mi lane?** Técnico → sí decido. Severidad/QA → Julieth. Scope/outcome/priorización → Nicole propone, Ignacio valida. Si es de otro → **ruteá** con el insumo, no decidas por él.
3. **¿Es validación de producto?** (alcance, problema, outcomes, priorización, criterios de salida) → es etapa PREVIA de Ignacio. Aportá insumo técnico, no cierres el alcance ni uses "acordado/cerramos".
4. **Aplicá los criterios técnicos** que correspondan (causa raíz no parche, no remover defensa `tenant_id`/RLS, CCC en RPC, invariante anti-regresión, observe→enforce, flags wired).
5. **Evitá los anti-patrones:** no reabrir una decisión cerrada (con evidencia nueva → pregunta citando la decisión), no adelantar el estado del issue, no mezclar propósitos en un PR.

## Salida

El encuadre: qué me toca decidir acá, qué reglas técnicas aplican, qué evitar, y a quién ruteo lo que no es mi lane.
