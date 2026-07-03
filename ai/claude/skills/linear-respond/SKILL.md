---
name: linear-respond
description: Responde una mención o pedido de Linear — clasifica si es un review (valida readiness del PR + estándar técnico) o una consulta (cuestiona la premisa desde producto antes de recomendar), orquesta las disciplinas (lane, producto, verificacion, voz) y devuelve el borrador. NUNCA postea — César publica. Triggers — "/linear-respond <ID>", "respondé <ID>", "revisá <ID>". Idealmente después de /linear-lore.
---

# linear-respond — responder (rutea review / consulta)

Toma el insumo de comprensión (de `/linear-lore`) y produce el borrador de respuesta. **Orquesta** las disciplinas model-invoked; no reimplementa su lógica. **NUNCA postea — César publica.**

**Input:** `<ISSUE-ID>` (+ opcional `--pr <N>`). Si no venís de `/linear-lore`, entendé primero el issue (leé issue + hilo) o sugerí correrlo.

## 0 · Encuadrar (siempre)

Corré `lane`: ¿esto es mi lane técnico, o es decisión de producto / QA / scope de otro? Si es de otro → la respuesta correcta es **rutear** (Ignacio / Nicole / Julieth) con el insumo, no resolver. Si es validación de producto (alcance, priorización) → aportá insumo técnico, no cierres el alcance (T5).

Clasificá el tipo (insumo de lore): **review** → §1 · **consulta / duda** → §2 · **mención / acuse** → respuesta directa breve (§3).

## 1 · Flujo REVIEW (un dev pide revisar un PR)

Tu revisión técnica es el **PRIMER paso**, previo al code-review de Ignacio + QA.

1. **Readiness primero** — corré `verificacion` con `reglas-readiness/beat.md`: issue In Progress · par de PRs app+BO mismo branch · labels `deploy:staging`+`deploy:preview` · ADLC Gate `PASSED` · mergeable. **Si falta algo → devolución de readiness** ("falta X para revisar"), NO entres al código.
   - El **estado del issue** (In Progress) verificalo en vivo con `linear-pp-cli issues <ID> --data-source live --agent --select identifier,state.name,url` (`live` obligatorio); el resto del readiness (PRs, labels, gate, mergeable) es de GitHub.
2. **Estándar técnico** — si readiness OK, revisá el PR contra los criterios técnicos de `lane` (causa raíz, no remover defensa, CCC en RPC, invariante anti-regresión, flags wired, observe→enforce). **[Opcional]** `/pr-review <PR>` para el análisis profundo — opcional porque el code-review de Ignacio normalmente lo levanta.
3. **Verificá los claims** con `verificacion` antes de afirmarlos (código de referencia / context7). Cero afirmaciones sin trazar a `ruta:línea`.
4. **Veredicto** — `APPROVE / APPROVE WITH CONDITIONS / CHANGES REQUESTED` + `MUST / SHOULD / CONSIDER` con `ruta:línea`. Tras el visto bueno, vos solicitás el code-review a Ignacio.

## 2 · Flujo CONSULTA (duda técnica / "¿qué plan elijo?")

NO elijas entre las opciones que trae el dev — **cuestioná la premisa**.

> **Dedup primero** — si el pedido podría ya existir como issue (bug, seguimiento), corré `linear-pp-cli issues search "<términos clave>" --agent` (FTS5 local, refresca solo si está stale). Si hay un issue similar, la respuesta correcta es **enlazarlo**, no tratar el pedido como nuevo.

1. **Cuestioná desde producto** — corré `producto`: ¿cuál es el outcome real? ¿la solución está sobredimensionada? ¿hace falta hacerlo ahora? (caso típico: te piden elegir entre A y B cuando el outcome no necesitaba ninguna). Si amerita profundizar el cuestionamiento → sugerí `/grill`.
2. **Encuadrá** con `lane`: ¿la decisión es mía (técnica) o de producto (Ignacio / Nicole)?
3. **Verificá** cada claim de código / librería con `verificacion` antes de recomendar.
4. **Decidí con criterio** — recomendá con razonamiento (negocio, simplicidad, riesgo), no ratifiques la premisa. Si el alcance está mal, proponé el recorte como decisión binaria (mantener vs reducir).

## 3 · Formato y cierre (ambos flujos)

- Pasá el borrador por `voz`: @mención al destinatario al inicio, español neutro y humano, no extenso, lo denso (reporte de pr-review, diff) en un bloque ``` .
- **Auto-chequeo antes de mostrar:** ¿no invado otro lane? ¿no reabro una decisión cerrada? ¿cada claim está verificado o marcado ❓? ¿pasó por `voz`?
- **Estado binario — LISTO o BLOQUEADO, nunca a medias.** Si al borrador le falta un dato que solo César tiene, o un claim sin verificar, está **BLOQUEADO**: NO lo entregues en bloque limpio para copiar — un hueco (`<completar>`, un valor que no tenés) se publica por accidente. Mostrá qué falta y ofrecé completarlo o partir la respuesta; el borrador en bloque sale **recién cuando está entero**. "Tu chequeo" es para verificar, nunca para tapar un hueco.
- **Mostrá el borrador para revisión. NUNCA postees — César publica.** Cerrá con **"Tu chequeo"**: lo que solo César debe confirmar antes de publicar.

> Fuera de Beat: si el proyecto no tiene `reglas-readiness/<proyecto>.md`, el readiness es manual (sin verificación automática) — decílo y no apliques las reglas de Beat a otro repo.
