---
name: linear-respond
description: >
  Responder una mención de Linear. El GAUGE mide la profundidad y rutea: pesado (code review con
  pr-review + lente Principal Engineer + filtro Ignacio) o liviano (respuesta directa tipo chat).
  Explica antes de draftear; pasa por el gate; NUNCA postea (César publica). Fusiona los antiguos
  review+reply en un solo comando. Triggers: "/linear-respond", "respondé <issue>", "revisá <issue>".
---

# Linear Respond — responder (carril único, el GAUGE rutea)

Lee primero el contrato: `~/.claude/skills/_shared/linear-contract.md` (B2 spine, B3 memoria, núcleo de guardrails, escalera). No re-describas su maquinaria.

**Input:** `<ISSUE-ID>` (requerido). Opcional `--pr <N>`, `--depth trivial|acotado|sustancial`.

## 0 · Contexto de proyecto (OBLIGATORIO — applicability gate del contrato)
Detectá el proyecto (tabla del contrato: team/labels/repo). **`rr` → seguí al GAUGE.** Cualquier otro (`fuerza`/`sl`/`engagement`/`app`/`unsupported`) → **DEGRADÁ explícito**: prepará el contexto (issue + hilo + diff resumido) **sin veredicto automático** y decílo: "el pipeline no está tuneado a este repo — review manual". Nunca apliques heurísticas/detection-rules de R&R fuera de R&R. El gate solo cita criterios/lecciones cuyo `applies_to` matchee.

## 1 · GAUGE — medir profundidad (rutea)
Con metadata del PR / naturaleza de la mención (`gh pr view` — files+diffstat, **sin checkout**). Lee `review/issue/{ID}/gate` (best-effort) si ya hubo decisión previa.

| Nivel | Señales | Ruta |
|---|---|---|
| **Trivial / no-código** | pregunta/decisión/acuse/routing; o solo tests/docs/typo/rename | **Liviano** (§3) |
| **Acotado** | 1 módulo, 1 concern, sin superficie de riesgo | **Pesado**, 1 dimensión (§2) |
| **Sustancial** | lógica de negocio, varios módulos, riesgo (`supabase/functions`, migraciones, auth/RLS, manager/dept/team), cross-cutting | **Pesado**, completo (§2) |

**Ante la duda, subí un nivel. Muestra + confirmá** la profundidad antes de gastar el pipeline pesado. Guardá la decisión en `review/issue/{ID}/gate` (B3).

## 2 · Ruta PESADA (code review)
0. **Pre-flight de review — VALIDAR LA SOLICITUD ENTRANTE (lección RYR-111 — OBLIGATORIO antes de gastar pipeline):**
   Una pedida de review formal solo se atiende si está bien formada. Dos checks sobre la PEDIDA (el comentario del dev que solicita la review), no sobre tu borrador:
   - **Loop informado en la pedida:** el comentario de solicitud debe mencionar a **@juli** (QA es el paso siguiente) y a **@ignacio** (revisión/merge). Leé el comentario exacto (`comment_id` de la mención) y verificá ambas menciones. Si falta cualquiera → la pedida está mal formada.
   - **Estado del issue:** `get_issue({ID})` → debe estar en **`In Review`**. Una review formal con el issue en otro estado rompe el ciclo.
   - **Si CUALQUIERA falla → PARÁ la ruta pesada.** NO corras la review ni emitas veredicto. Borrador correcto = **devolución de proceso** (liviana): "para atender la review formal falta {estado In Review / cc a @juli / cc a @ignacio} — corregí y re-solicitá". Solo César puede ordenar continuar igual (override explícito).
   - **Snapshot para el hook:** persistí el estado consultado: `echo "{\"state\":\"<estado>\",\"checked_at\":$(date +%s)}" > ~/.claude/cache/linear-state/{ID}.json` — el hook `linear-write-guard.sh` lo re-valida al publicar (frescura 30 min; re-consultá si expira).
0.5. **READINESS del PR — VERIFICAR ANTES DE REVISAR CÓDIGO (orden de César; readiness §1 de `readiness-y-evaluacion-pr-issues.md`).** Tu revisión es el paso **PREVIO** al core review de Ignacio — **no en paralelo** (el "QA ‖ code review" de Ignacio es Julieth arrancando QA junto al code review, NO Ignacio revisando junto a vos). Como *stopper técnico*, antes de gastar el pipeline de código confirmá que el PR está **listo de verdad**:
   - **Pipeline verde** — los checks de CI/ADLC corrieron y pasaron (tests unitarios + servicios): `gh pr checks <PR>`. Rojos o pendientes → no está listo.
   - **Preview levantado en el ADLC correcto** — entorno de preview arriba (label `deploy:preview` activo).
   - **Mergeable** — sin conflictos con la base: `gh pr view <PR> --json mergeable,mergeStateStatus`.
   - **Si falta algo → NO revisés el código a fondo.** El borrador correcto **señala qué falta para estar listo** ("el pipeline está en rojo en {check}", "falta levantar el preview"), como readiness, no como rechazo del código.
   - **Las URLs de validación** (run del pipeline, preview) las verificás **vos** → van a **"Tu chequeo"**, NO al comentario público (salvo que aporten al destinatario).
1. **📖 UNDERSTAND** — explicá en lenguaje simple qué pide el issue y **qué propone el PR** (esto va ANTES del borrador). Guardá en `review/issue/{ID}/pr-summary` (B3).
2. **Correctness** → corré `/pr-review <PR>` (su pipeline 2-pass + su registry de domain-rules por trigger). Código vía lector de 3 capas del triaje Pass 2 (clones read-only, nunca mutar).
3. **Intención (lente Principal Engineer)** — ¿el PR resuelve lo que el issue pide? trade-offs, esfuerzo proporcional, ¿alternativa más simple?
4. **Filtro Ignacio** — cruzá contra `ignacio-review-criteria.md` + engram (advisory, se cita; respeta lo cerrado).
5. **Lente producto (kernel)** — K1-K6 del canon (`product-decision-canon.md`, B2 del contrato); hallazgos fraseados como insumo para el dueño del scope, nunca veredicto de alcance.
→ Borrador con veredicto estructurado (B2).

## 3 · Ruta LIVIANA (respuesta directa)
Lee el hilo → borrador confiado tipo chat, sin estructura de veredicto. No toca código.
Si el draft plantea un curso de acción (modo PROPUESTA del contrato): el gate corre además el kernel K1-K6 del canon (B2). Propuesta/análisis de producto completo → sugerí `/product-lens` antes de draftear.

## 4 · Gate + present (B2 — 3 filtros, 3 anillos)
Pasá el borrador por el **gate** (B2 del contrato): evaluador fresco, salida por criterio, **fail-closed**. `respond` corre el **perfil completo** del gate (pertinencia + calidad + credibilidad; ver contrato B2 · Perfiles); el atajo de solo-forma para pulir un texto suelto sin contexto de issue es `/linear-voice`. Corre el **pre-gate de PERTINENCIA primero** (P1-P4: ¿mención real? ¿pedida bien formada? ¿le toca a César? ¿sigue abierta?) — si falla, el borrador NO es respuesta de contenido: devolución / ruteo / no-responder, sin evaluar el resto. Si pasa, corre **calidad** (incluye Criterio 10 — español mexicano neutral) y **credibilidad**.

Anillos:
- **Anillo 1** (siempre) — el evaluador Claude fresco corre los 3 filtros.
- **Anillo 3** (si el veredicto cita `file:línea`) — escribí el borrador a un temporal y corré `~/.claude/skills/_shared/scripts/verify-citations.sh <borrador> <clone-local> <ref-del-PR>`; **cualquier FAIL degrada APPROVE→CONDITIONS** (⚠️ cita no verificable).
- **Anillo 2** (SOLO ruta PESADA — GAUGE acotado/sustancial) — cross-model sobre forma/idioma. Prompt ACOTADO (patrón de `linkedin-post` §4): rol + checks cortos (¿español mexicano neutral profesional, sin localismos? · ¿naturalidad, sin sonar a traducción? · ¿responde lo que se preguntó?) + el borrador + "responde SOLO PUBLICABLE/AJUSTES/MEDIOCRE y qué falla, máx 5 líneas":
  ```bash
  timeout 120 pi -p --provider openai --no-tools "<prompt acotado>"   # NO pasar --model (usa gpt-5.5 por suscripción)
  ```
  Consenso fail-closed: publicable solo si anillo 1 **y** anillo 2 dan ✅; discrepancia → gana el más estricto → reescribe ≤2 vueltas con el feedback combinado.

Presentá: explicación → borrador → veredicto/⚠️ → estado del gate (✅ listo / ⚠️ no publicable). **César publica.**

Si surge una corrección / criterio / miss → **sugerí `/linear-learn`** (no guardes la lección directo — el dedup vive ahí).
