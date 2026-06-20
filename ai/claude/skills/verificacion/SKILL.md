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

## Leer código de Beat sin alucinar

Clones **read-only** en `~/Code/work/rr-project/`: front `app-rr-cesar` (`ivaldovinos-app/ryr-39255`), back `back-pulse-cesar` (`ivaldovinos-app/apprecio-pulse`). `git -C <base> fetch -q` y `git -C <base> grep -n '<patrón>' <ref>` leen cualquier rama **sin checkout**. NUNCA `checkout` / `pull` / `merge` en los clones.

Guardas (las que evitan el falso positivo):
- Confirmá que el componente está **renderizado** (grep su uso — el dead code es trampa).
- Seguí el **campo exacto** que consume la UI; "correcto en otro lado" ≠ "correcto en el campo consumido".
- La RPC / función backend es la definición **más nueva** (`CREATE OR REPLACE` — grep todas, leé la última).
- Para la **completitud de un fix**, enumerá los paths hermanos (un fix sobre un campo/constraint compartido debe cubrir todos sus writers).
- **Feature flags:** antes de recomendar "seed `<flag>`", `grep_repo(pulse,'<flag>')` — **0 matches = nunca fue flag backend → el fix es quitar el gate en el front**, no seedear (mandar a Soporte a perseguir un fantasma es el peor falso positivo).

## Readiness de un PR

Cargá `reglas-readiness/<proyecto>.md` y verificá cada regla con `gh`. El archivo de reglas es **DATA** — para sumar un check o un proyecto nuevo, se edita ese archivo, no este skill.
