---
name: linear-learn
description: >
  Captura un aprendizaje del flujo Linear y lo persiste DURABLE para que el gate de /linear-respond lo
  reuse al validar — así no se repite el error. Su valor no es guardar (eso es mem_save) sino DESTILAR la
  regla durable, DEDUPLICAR y RUTEAR. Triggers: "/linear-learn", "esto es un aprendizaje", "que no se repita esto".
---

# Linear Learn — capturar aprendizaje (cierra el loop)

Contrato: `~/.claude/skills/_shared/linear-contract.md` (B4 learn, B3 memoria, registry). Único lugar donde se capturan lecciones — los demás comandos **sugieren** `/linear-learn`, no guardan directo (el dedup vive acá).

**Input:** `<source>` opcional (un `ISSUE-ID`, `session`, o una nota de César). Sin source → proponé candidatos de la conversación.

## Señales (qué amerita capturar)
Corrección de César · rechazo/criterio de Ignacio · miss del gauge/gate · regla de proceso acordada · root cause no obvio que puede recurrir.

## 1 · Destilar (durable, no volátil)
Extraé **la regla** + una línea **"cómo aplicarla en review"** + metadata obligatoria: **`applies_to:`** (`rr` | `all` | lista de proyectos) y **`last_confirmed:`** (fecha de hoy). Sin esa metadata el gate no puede citarla como bloqueante (>90 días sin confirmar → se degrada a soft). ❌ No guardes `file:línea`/estado-PR/diff como verdad (eso se re-lee fresco).

**Tension-check (coherencia con producto):** si la regla destilada restringe o contradice un principio de la capa 1 del canon (`_shared/product-decision-canon.md`) → se registra CON su matiz en la tabla de tensiones del canon, o se levanta el conflicto a César. La coherencia se chequea cuando nace la regla, no en auditorías.

## 2 · Rutear
| Tipo | Canónico (vault, ruta absoluta) | Espejo engram (`scope: personal`) |
|---|---|---|
| Lección review/proceso | `linear/knowledge/linear-review-lessons.md` | `review/lessons/{slug}` |
| Criterio/rechazo Ignacio | `linear/knowledge/ignacio-review-criteria.md` | `review/ignacio/criteria` |
| Concepto/caso de decisión de producto, o tensión con la capa 1 | `_shared/product-decision-canon.md` | `product/decision-canon-y-skill-product-lens` |
| Calibración gauge/gate de un issue | — | `review/issue/{ID}/gate` |
| **Check de código particular** | **registry de pr-review** (`knowledge/detection-rules/`) con su trigger | — |

Vault = verdad; engram = acelerador. Ver B3.

## 3 · Deduplicar (anti-bloat de memoria)
**Antes de guardar:** `mem_search` + leé el archivo canónico. Si ya existe la regla → **actualizá** (mismo `topic_key` / misma entrada), NO crees duplicado. 1 regla = 1 entrada.

## 4 · Guardar + conflicto
Escribí al archivo canónico del vault + `mem_save`/`mem_update` (`scope: personal`). Seguí el conflict-surfacing protocol (`CLAUDE.local.md`): si `judgment_required`, `mem_judge` por candidate; preguntá a César si confidence < 0.7 o relación `supersedes`/`conflicts_with` sobre policy/decisión.

## 5 · Confirmar
Mostrá: la regla destilada · dónde quedó · **qué gate/criterio la consumirá** en reviews futuros.

## Fuera de scope (anti-bloat)
NO escanear "todo Linear" buscando lecciones. Se aprende de una fuente puntual o de la sesión. La memoria crece por uso real.
