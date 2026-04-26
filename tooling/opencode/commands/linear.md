---
description: Radar del equipo — Linear + estado-semana cruzado, delivery health y blockers
---

# /linear — Radar PE del Equipo

Analiza el estado del equipo cruzando Linear (realidad operativa) con estado-semana (compromisos).

Uso:
```bash
/linear
/linear samuel
/linear --blockers
```

## Contexto fijo

- Vault: `docs-projects`
- Estado semana: `_work/apprecio/estado-semana.md` (seccion "Estado del Equipo")

Miembros:
- Samuel: `3e1e34b6-b368-44fb-9905-8ba595058ae4`
- Faber: `a610cc2e-6123-4711-b6ba-d2f038dce5a6`
- Kevin: `1d2fb141-6dc1-4d81-babd-33a274528009`
- Nicole: `74892295-d834-4351-b7f2-a39633bf01d3`
- Julieth: `d59d2ef5-330f-40bd-8314-7a99da2c7e35`
- Ignacio: `1f03f08d-db10-4bf2-8999-499b7842f50c`

## Modos

### Default (`/linear`)

1) Consultar Linear por persona:
- started y unstarted por miembro
- calcular workload, ultimo movimiento, stale >3d, items en review/qa

2) Consultar bloqueados globales:
- issues en estado blocked
- issues unstarted sin assignee (huerfanos)

3) Leer estado-semana:
- seccion Estado del Equipo
- compromisos, bloqueos reportados, ultimo update

4) Entregar output:
- detalle por persona
- bloqueados con quien desbloquea
- alertas PE (definition, execution, ownership, predictability)
- resumen tabular

### Persona (`/linear <nombre>`)

- Deep dive de una persona:
  - issues activos, bloqueados y completados recientes
  - comentarios recientes
  - compromisos vs realidad
  - riesgos y accion sugerida

### Bloqueos (`/linear --blockers`)

- Solo cadena de bloqueos, dependencias y accion de desbloqueo.

## Reglas

- Solo lectura en Linear (no crear, actualizar, cerrar issues).
- Si Linear no esta disponible, degradar al estado-semana con warning claro.
- Hora local: America/Santiago.
- Divergencias reunion vs Linear se tratan como senal operativa, no juicio personal.
