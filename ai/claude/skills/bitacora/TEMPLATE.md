Plantilla de `00-bitacora.md`. `crear` y `adoptar` la usan: copian, rellenan placeholders `<…>` y
escriben en `issues/<ID>/`. Lo que no se sepa va literal como `<pendiente>` (nunca inventar).

```markdown
---
type: nota
project: <slug>
issue: <ID>
date: <YYYY-MM-DD>
status: active
related_to: []
---

# <ID> · Bitácora — <título>

> Fuente de verdad para retomar sin releer. **Léeme primero.** Última actualización: <YYYY-MM-DD>.

## Estado actual / próximo paso
<una línea: dónde está y qué sigue — lo primero que necesita una sesión nueva>

---

## Nivel 1 · Producto
> Tus decisiones ya condensadas (de Linear, transcripciones, Drive…). No las fuentes crudas.
- **Outcome / problema:** <qué resultado mueve; para quién>
- **Criterios de aceptación:** <…>
- **Fuera de scope:** <explícito — qué NO se hace; corta el "asumir de más">
- **Decisiones de producto:** <con fuente: quién / dónde / cuándo>

## Nivel 2 · Seguimiento (técnico + implementación)
- **Línea base (qué hay hoy):** <archivo:línea · módulos>
- **Enfoque elegido + trade-offs:** <…>
- **Alternativas descartadas y por qué:** <corta el re-litigar>
- **Riesgos / gotchas:** <…>
- **Hecho (y verificado):** <archivos · commits · PRs>
- **Pendiente:** <…>
- **Docs profundos:** <[[wikilink]] a análisis/seguimiento si el issue creció>

---

## Decision-log · decisiones y pivoteo (el corazón)
> Append-only. El pivoteo viejo NUNCA se borra — el valor está en la historia.
- `<YYYY-MM-DD> — [prod|téc|impl] <decisión> — porque <razón> — fuente: <…>`
- `<YYYY-MM-DD> — [pivote] de <X> → a <Y> — porque <razón> — fuente: <…>`   ← reemplaza, no borra
```
