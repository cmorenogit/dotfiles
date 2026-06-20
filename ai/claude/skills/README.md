# Skills — índice y ruteo

Conocimiento **operativo** del sistema de skills. Vive acá (global, con los skills), no en el vault — los skills no dependen del vault para funcionar. El *porqué* de cada diseño es backup/memoria en el vault (`~/Code/_vault/_personal/dotfiles/claude-code/skills/`).

## Sistema Linear

| Skill | Tipo | Hace | Consume |
|---|---|---|---|
| `linear-lore` | user-invoked | entender un issue (resumen claro + situación + tipo) | Linear |
| `linear-respond` | user-invoked | responder: rutea review / consulta; orquesta las disciplinas | las de abajo |
| `voz` | model-invoked | humaniza la respuesta + @etiqueta + ``` ``` para lo denso | — |
| `producto` | model-invoked | cuestiona la premisa desde producto | vault `_shared/producto.md` |
| `lane` | model-invoked | encuadra rol, límites y gobernanza de César | vault `_shared/lane.md` |
| `verificacion` | model-invoked | nada se afirma sin evidencia real + readiness de PR | `reglas-readiness/*.md` |
| `pr-review` (+ `ccc`/`audit`/`scope`/`tests`/`fp`) | user/model | motor de review de código de Beat | `pr-review/knowledge/` |
| `grill` | user-invoked | afinar un plan/diseño antes de construir | — |

**Conocimiento de dominio** (Apprecio): `producto.md` · `lane.md` viven en el **vault** (`_work/apprecio/_shared/`, cerebro). Los criterios de review de **código** viven en `pr-review/knowledge/`.

## ¿Dónde va una regla nueva? — "¿de qué trata?"

| La regla trata de… | Va a |
|---|---|
| si **el código está bien** (seguridad técnica, arquitectura, tests, migraciones, contratos) | **`pr-review/knowledge/`** |
| si **la decisión de producto está bien** (outcome, scope, riesgos, priorización) | **vault `producto.md`** |
| **tu rol o tu forma de trabajar** (qué te toca, qué rutea, gobernanza de accesos/secretos, cómo te comunicás) | **vault `lane.md`** |
| **cómo confirmás un dato** (evidencia real) | **`verificacion`** |
| **cómo suena la respuesta** | **`voz`** |

**Desempate (frontera):** ¿la regla **gobierna tu comportamiento** (sin importar el objeto) → `lane`; o **juzga el objeto** → `pr-review` (código) / `producto` (decisión)? `pr-review` y `producto` juzgan un artefacto externo; `lane` te gobierna a vos. Por eso un criterio de código nunca va en `lane`.

> Higiene de seguridad (no exponer secretos/accesos por canal público) hoy es **una regla de `lane`** (gobierna a César). Se graduaría a skill `seguridad` propio solo si aparece seguridad transversal más allá del rol — PII, datos de clientes — que cualquier respuesta deba consultar. *Placing bets con evidencia, no por las dudas.*

## Convenciones (writing-great-skills)

- **user-invoked vs model-invoked:** un user-invoked (lo tipeás) puede llamar model-invoked, nunca otro user-invoked.
- **Single source of truth:** cada regla en un solo lugar (ver ruteo). Duplicar = drift.
- **Skill = proceso; el conocimiento pesado va en `.md` referenciados** (vault para dominio, `knowledge/` para código).
- **No-op test:** si el modelo ya lo haría por default, no lo escribas.
- Método completo: https://github.com/mattpocock/skills

## Diseño (el porqué)

Las decisiones y trade-offs de cada sistema viven en el vault como memoria: `~/Code/_vault/_personal/dotfiles/claude-code/skills/`.
