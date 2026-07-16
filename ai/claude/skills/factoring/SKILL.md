---
name: factoring
description: Copiloto de inversión en factoring de Finsmart. Toma el informe crudo que Finsmart publica por Telegram antes de cada turno (12:30 / 17:30 hora Lima), lo parsea, lo puntúa con un criterio de riesgo-retorno y devuelve un PLAN DE EJECUCIÓN de dos tiempos (qué asegurar primero porque se satura, qué te espera, qué queda fuera y por qué) listo para ejecutar a mano cuando abre la plataforma. Prepara la decisión; NO invierte. Triggers — "/factoring", "analizá este informe de Finsmart", "dónde invierto este turno", "rankeá estas operaciones", pegar un informe con "Hora de publicación en plataforma".
---

# factoring — copiloto de inversión Finsmart

Convierte el informe de Finsmart (pegado como texto crudo de Telegram) en un **plan de ejecución** para la apertura del turno. El objetivo es llegar a las 12:30 / 17:30 con la decisión ya tomada, porque la plataforma se satura y las buenas operaciones se llenan rápido.

**Límite duro:** este skill **prepara**, no ejecuta. César invierte a mano en Finsmart. Nunca sugerir automatizar la inversión.

**La data es de Finsmart** (la contraparte interesada). No se verifica contra fuentes externas en esta versión — el plan es tan bueno como lo que reporta el mensaje. Decirlo si algún dato huele raro.

## Input

Texto crudo pegado desde Telegram. Puede traer ruido (headers "Finsmart", timestamps sueltos "11:41", typos de la fuente) y **uno o varios turnos mezclados**. Cada operación es un bloque; el turno se identifica por el campo `Hora de publicación en plataforma: DD/MM/AAAA - HH:MM`.

## Preferencias de César (config)

- **Moneda:** solo **soles (S/)**. Todo lo que esté en dólares se descarta antes de puntuar.
- **Plazo:** prioridad a **≤60 días**; más largo penaliza progresivamente, pero **no descarta** (no es estricto).
- **Objetivo:** rapidez (llegar preparado) + mejor inversión **ajustada a riesgo**. El riesgo manda sobre el retorno: 2 puntos de tasa no compensan un impago.

## Proceso

1. **Parsear y agrupar.** Extraé cada operación; limpiá el ruido. Agrupá por turno (`Hora de publicación en plataforma … - HH:MM`). Todo lo que sigue se hace **por turno**.
2. **Filtro duro — moneda.** Si el `Monto` no está en `S/` (p. ej. `$`), descartar y no mostrar en el plan (listar aparte en "Descartadas por filtro").
3. **Bandera roja — protestos.** Si `Protestos sin aclarar > 0`: la operación va **fuera del plan por default**, al fondo, marcada 🔴 con el motivo y el monto. No se elimina en silencio: César puede hacer la excepción viéndola.
4. **Score de calidad** (0–100) — sección siguiente. Determinístico: aplicar la tabla de puntos tal cual.
5. **Ajuste de plazo** — multiplicador sobre el score de calidad.
6. **Orden de ejecución** — eje de saturación por monto (chico = primero).
7. **Umbral / pasá de largo** — si nada supera el mínimo, decirlo explícito.
8. **Juicio cualitativo** — usar las notas en prosa (respaldo de grupo, `CPP` en centrales, tendencia de facturación) solo para **matizar y desempatar**, nunca para saltarse una regla dura.

## Score de calidad — tabla de puntos (determinístico)

Sumar. El orden de los pesos refleja *riesgo primero, retorno después*.

| Componente | Puntos | Cómo asignar |
|---|---|---|
| **Rating Finsmart** | 0–30 | A+ = 30 · A = 26 · B+ = 20 · B = 14 · C+ = 8 · C = 4 · inferior = 0 |
| **Tipo** | 0–15 | Confirming = 15 · Factoring = 7 |
| **Historial Finsmart** | 0–20 | *Volumen* (# finalizadas): ≥300 = 10 · 100–299 = 8 · 30–99 = 5 · <30 = 2. **+** *Mora promedio*: 0d = 10 · ≤1d = 7 · ≤3d = 4 · >3d = 0 |
| **Solidez del pagador** | 0–20 | *Antigüedad*: ≥15a = 5 · 8–14a = 4 · 4–7a = 2 · <4a = 0. **+** *Tamaño* (trabajadores/facturación): grande (>500 trab o >S/200M) = 5 · mediano = 3 · chico (<50 trab) = 1. **+** *Tendencia facturación*: creciente = 5 · estable = 3 · cayendo = 1. **Ajustes:** no agente de retención −2 · garantías hipotecarias que cubren su deuda directa +2 · `CPP`/clasificación negativa en centrales −3. Cap 0–20 |
| **Tasa anualizada** | 0–15 | ≥13% = 15 · 12–12.9% = 11 · 11–11.9% = 7 · <11% = 4 |

**Score de calidad = suma (máx 100).** El desglose (qué sumó, qué banderas/ajustes) se muestra — nunca un número pelado.

### Ajuste de plazo (multiplicador sobre el score)

- ≤60d → ×1.00
- 61–90d → ×0.92
- 91–120d → ×0.82
- >120d → ×0.70

**Score final = calidad × plazo.** Ese es el número de ranking.

### Orden de ejecución (eje de saturación)

Dentro de las **aprobadas** (pasan el umbral, sin bandera roja):

- **🟢 Asegurá primero** — monto **< S/ 20,000** (se saturan rápido). Ordenar por score final.
- **🟡 Con calma** — monto **≥ S/ 20,000** (te esperan). Ordenar por score final.

Idea: primero agarrás lo bueno-y-que-se-evapora; después completás con lo bueno-que-te-espera. El umbral de S/ 20k es heurístico y **calibrable** con la experiencia de César.

### Umbral / pasá de largo

- Score final **< 45** → **fuera del plan** ("no vale la pena"), listada abajo con su motivo.
- Si **ninguna** operación del turno supera 45 → decir claro: **"Pasá de largo este turno"**. No forzar una elección.

## Output (formato fijo)

```
# Plan Finsmart — <fecha del informe>

## Turno <HH:MM> · <N> operaciones

### 🟢 Asegurá primero (se saturan)
1. <EMPRESA> · S/ <monto> · <tasa>% · <días>d · <rating>/<tipo> — <una línea: por qué / score>

### 🟡 Con calma (te esperan)
2. <EMPRESA> · … — <por qué>

### 🔴 Fuera del plan
- <EMPRESA> — <bandera: protestos S/…, o score < 45>

### Descartadas por filtro
- <EMPRESA> — moneda ≠ soles

**Veredicto del turno:** <1–2 líneas: dónde poner el foco, o "pasá de largo">
```

Después del plan, incluir una sección **`<details>` "Detalle del scoring"** con la tabla por operación (componentes → score calidad → ×plazo → final) para que César audite y calibre.

Cerrar recordando en una línea: *data no verificada de Finsmart · vos ejecutás*.

## Notas de calibración (v1 — ajustable)

Este criterio es la **v1** y está pensado para iterar con turnos reales. Lo más probable de ajustar:

- Pesos de la tabla (¿confirming debería pesar más? ¿la tasa menos?).
- Umbral de saturación (S/ 20k) según qué tan rápido se llenan de verdad.
- Umbral de corte (45) según cuántas operaciones querés ver.
- Protestos: hoy es semáforo al fondo; si molesta el ruido, se puede escalar por monto del protesto.

Cuando el criterio deje de cambiar, la parte determinística (tabla de puntos + plazo + orden) conviene extraerla a un **script** para volverla gratis, instantánea y 100% reproducible, dejando el LLM solo para el juicio cualitativo. No hacerlo todavía.

Ignorar importaciones/exportaciones para el score (son actividad comercial, no señal de pago).
```
