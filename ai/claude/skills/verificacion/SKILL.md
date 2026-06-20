---
name: verificacion
description: Verifica un claim o el readiness de un PR contra evidencia real (código de referencia, context7 para librerías, web search) antes de afirmarlo — reporta PASS o qué falta, nunca asume. Úsalo cuando una respuesta afirma un hecho de código/librería/dato, o para validar que un PR está listo. Evita los falsos positivos de afirmar sin trazar.
---

# verificacion — nada se afirma sin evidencia

Mecanismo para que ningún claim entre a una respuesta sin trazarse a una fuente real. Reporta **PASS** o **qué falta** — nunca asume ni rellena.

## Flujo

1. **Identificá el claim** a verificar (un hecho de código, una API de librería, un dato externo, o el readiness de un PR).
2. **Elegí la fuente por tipo de claim:**

   | Tipo de claim | Fuente |
   |---|---|
   | Código del repo (existe / hace X / en `ruta:línea`) | clones read-only (`git grep` sin checkout), `gh`, pm-agents `grep_repo` |
   | API / config de una librería o framework | **context7** (docs frescas) |
   | Hecho externo / actual | **web search** |
   | Readiness de un PR | `reglas-readiness/<proyecto>.md` + `gh` |

3. **Verificá.** Trazá a `ruta:línea` / URL / output real. Si no alcanzás la fuente → marcá ❓ y nombrá el check decisivo; no lo des por cierto.
4. **Reportá:** PASS (con la evidencia) | FALTA (qué no se pudo confirmar). Una memoria/caché > ~48h se re-verifica fresca antes de contar como PASS.

## Readiness de un PR

Cargá `reglas-readiness/<proyecto>.md` y verificá cada regla con `gh`. El archivo de reglas es **DATA** — para sumar un check o un proyecto nuevo, se edita ese archivo, no este skill.
