---
name: linear-today
description: >
  Hub diario y guardián de foco del flujo Linear de César. Escanea menciones pendientes, mide cuánto
  review amerita cada una (GAUGE) y las encola SIN sacarlo del issue en curso. Para /loop (~30min) como
  buffer de interrupciones. Sugiere lane; nunca dispara lo pesado ni postea. Triggers: "qué hay hoy en
  Linear", "/linear-today", "/loop … /linear-today", "qué llegó".
---

# Linear Today — hub diario + guardián de foco

Contrato: `~/.claude/skills/_shared/linear-contract.md` (B1 scan, GAUGE, B3 memoria, núcleo de guardrails).

Buffer de interrupciones: absorbe lo que llega, lo mide y lo encola, y **no saca a César del foco** hasta que él decide cortar. **Nunca postea ni corre el pipeline pesado.**

## Pasos
1. **Detección + clasificación** → B1 del contrato (delega al triaje §1-2). Ventana default `2d`; el recorte "hoy" lo da el delta. **No** corras el gate de borradores — acá no se redacta.
2. **Resolución de flujo + "necesita de vos" (feedback César 11/06)** — por cada candidato, leé el flujo POSTERIOR a la mención: si el autor se auto-respondió, otro cerró el punto, o la conversación avanzó sin esperar a César → degrada con evidencia (cita del comentario que lo cerró). Cada item del board lleva OBLIGATORIO el campo **`Necesita de vos:`** {acción mínima concreta | decisión | solo contexto | nada — cerrado solo}. **Nunca "te mencionaron, contestá".**
3. **GAUGE** → tabla del contrato. Solo para sugerir el lane de cada 🔴 (no rutea, no gasta pipeline). Recordar: el lane de César es *validación de estándar técnico* — el code review formal es de Ignacio (regla 11/06, `8763ae44`).
4. **Alertas de flujo (gaps)** → B6 del contrato (la tabla completa de señales vive AHÍ — incluye las 3 del canon de producto: priorización post-hoc, pieza bloqueada comprometida, compromiso sin plan a producción). Advisory, máx 3/tick, con cita + dueño del gap + intervención mínima.
5. **Buffer/delta (trabajo único):** leé la cola previa `~/Code/_vault/_work/apprecio/linear/today/today-{YYYY-MM-DD}.md`, calculá delta vs ella + `linear/scan-index.md`, y **surface solo lo nuevo/cambiado** (no re-vuelques lo igual). Actualizá la cola.

Cola (`today-{fecha}.md`): `| issue | necesita de vos | gauge | estado (nuevo/encolado/respondido) | nota |` + bloque `## Telemetría` (B5 del contrato: absorbidas · borradores usados/editados/rehechos · gate pass/fail real/falso · **fp_clasificador** — items que César marcó como "no necesitaba mi acción").

## Output — board corto (un vistazo)
```markdown
# Linear hoy — {HH:MM}  ·  {Δnuevos} nuevos · {Δcambios} cambiaron · {N} en cola
## 🆕 Nuevo
- **RYR-XX** · Necesita de vos: {…} · sustancial → `/linear-respond RYR-XX`
## ⚠️ Alertas de flujo — (B6: gap + cita + a quién le toca + intervención mínima)
## 🔁 Cambió — (…)
## En cola — RYR-YY (respondido), RYR-ZZ (decidí vos)…
```
Sin delta → una línea: **"Sin novedades desde {HH:MM}. Seguí en lo tuyo."**

## Loop / handoff
- `/loop 30m /linear-today` — **push-on-threshold**: el tick solo habla si hay ≥1 🔴 nuevo, un 🟡 que escaló a 🔴, **o una alerta de flujo B6 de alta confianza**; si no, exactamente UNA línea de silencio. **Nunca** dispara `/linear-respond` solo.
- 🔴 → `/linear-respond <ID>` (el GAUGE rutea pesado/liviano) · 🟡 → quedan en cola.

Memoria → B3 del contrato (vault canónico + engram `scope: personal`, best-effort).
