---
name: sintesis
description: Destila una reunión de Google Meet a LO QUE TE TOCA a César (no el resumen completo) — qué te toca, qué esperás de otros, qué quedó decidido, qué contexto. Lee el verbatim vía transcripcion.py y produce una síntesis personal clasificada en 4 cubetas, persistida por semana en el vault. Solo se invoca a mano (/sintesis). Triggers — "/sintesis <descripción de la reu>", "sintetizá el weekly del lunes", "qué me toca de la reunión con Samuel".
disable-model-invocation: true
---

# sintesis — lo que te toca, no el resumen

Convierte el verbatim de una reunión en **tu recorte**: lo que le concierne a César, clasificado y accionable. **No es el acta oficial ni el resumen de la reunión** (eso ya lo da Gemini) — es la lista de lo que te toca, separando lo accionable de lo que solo hay que saber.

Se para sobre `/transcripcion`: reusa su motor (`transcripcion.py`) para resolver y traer el verbatim, y de ahí destila. **El verbatim manda.** Las Notas de Gemini no se usan, salvo como fallback cuando no hay verbatim.

## Identidad de César — el recorte gira en torno a esto

"César" = `Cesar Moreno`, `Cesar`, `César`, `nfierro@apprecio.com`. Todo lo que clasifiques es **respecto a él**: ¿le toca a César? ¿lo espera César de otro? Ese recorte centrado en él es lo que distingue esta síntesis de un resumen genérico. Equipo para ubicar a quién es qué: Ignacio (jefe de producto, despliega), Julieth (QA), Nicole (producto), Samuel/Faber/Kevin/Jhoan (devs), Cristian (Incentivos/Core).

## Flujo

1. **Resolvé la reunión** (igual que /transcripcion): interpretá la query → `nombre` (persona/título) + `fecha` (relativa o absoluta) convertida a `YYYY-MM-DD` en GMT-5. Listá candidatos:
   ```sh
   python3 ~/.claude/skills/transcripcion/transcripcion.py list --name "Samuel" --after 2026-06-18 --before 2026-06-20
   ```
   `--name`, `--after`, `--before` opcionales. Resolvé por `count`: **1** → seguí · **>1** → mostrá lista numerada (`nº · título · fecha · owner`) y **esperá** que César elija · **0** → decílo y sugerí ampliar.

2. **Traé el verbatim:**
   ```sh
   python3 ~/.claude/skills/transcripcion/transcripcion.py get <DOC_ID>
   ```
   Devuelve `{path, title, date, owner, tab, turns, chars, ...}` y escribe el `.md` en `/tmp`. **Leé ese archivo** (entero, o por secciones con grep/offset si es enorme).

3. **Detectá la materia prima** por el campo `tab`:
   - `"Transcripción"` → verbatim completo, síntesis normal.
   - termina en `"(sin pestaña Transcripción)"` → **NO hay verbatim, solo resumen**. Avisá *"síntesis parcial — esta reu no tiene verbatim, la destilo del resumen"* y marcá el doc como parcial.

4. **Destilá a las 4 cubetas** (ver abajo) leyendo con el lente de César. **Conservador**: solo lo EXPLÍCITO. Si no nombran ni asignan algo a César, NO va en "Me toca".

5. **Generá el TL;DR**: 1-3 líneas, *de qué se trató desde el ángulo de César* (qué te toca encarar). Omitilo si la reu es trivial.

6. **Escribí el doc** en `~/Code/_vault/_work/apprecio/weekly/{YYYY-Www}/sintesis-{fecha}-{slug}.md`, donde `{YYYY-Www}` es la **semana ISO de la fecha de la reunión** y `{slug}` el título de la reu en kebab-case. Frontmatter + plantilla de abajo.

7. **Confirmá** y mostrá la síntesis en el chat.

## Las 4 cubetas (en 2 bloques)

**▸ ACCIÓN** — lo que mueve la aguja:
- **① Me toca** — acción o decisión que cae en César (incluye su rol de stopper técnico: dar veredicto, aprobar, definir el approach).
- **② Espero de otro** — algo que César necesita que otro haga (Ignacio despliega, Julieth valida, un dev entrega). Es seguimiento.

**▸ PARA SABER** — referencia, sin acción de César:
- **③ Quedó decidido** — decisión cerrada en la reu que cambia el mundo de César (no le asigna acción, pero importa; no re-litigar).
- **④ Contexto** — info relevante sin acción.

**Cubetas vacías se omiten.** Un 1:1 corto quizá solo llena ① y ②; un weekly denso, las cuatro. **Lo que no encaja en ninguna → descartalo** ("nada" no aparece).

## Reglas

- **Centrado en César, no en la reunión.** No resumas todo lo que pasó; recortá lo que le concierne a él. Si terminás describiendo la reunión completa, te fuiste a "resumen Gemini".
- **Conservador.** Solo lo explícito. Lo dudoso ("¿es de César o no?") NO va a ① — va a ④ como contexto, o se omite. Cero falsos "te toca".
- **Verbatim manda.** Sin verbatim (fallback) → síntesis parcial, avisada y marcada en el doc.
- **Header "con quién/qué".** En 1:1s importa de quién es el "espero de otro".
- **Sin Linear.** Si en el verbatim aparece un ID (RYR-7), citalo como texto. No crees ni comentes issues.
- **Citá cuando ancle.** Una frase corta del verbatim que respalde un item (`Ignacio: "lo despliego el viernes"`), sin pegar bloques.

## Formato del doc

```markdown
---
type: sintesis
project: _shared
date: <fecha de la reu YYYY-MM-DD>
status: done
---

# Síntesis — <reunión> · <día dd mmm aaaa>

> fuente: verbatim (<owner>) · <Doc URL del header de la transcripción>

De qué se trató: <TL;DR 1-3 líneas, centrado en César>

**▸ ACCIÓN**

**① Me toca**
- <item>

**② Espero de otro**
- <item>

**▸ PARA SABER**

**③ Quedó decidido**
- <item>

**④ Contexto**
- <item>
```
(Omití los bloques y cubetas vacíos. Si es parcial, agregá `> ⚠️ parcial: sin verbatim` bajo el header.)

## Guardado

`weekly/` está exento de la regla de consolidación del vault (el guard solo la aplica bajo `projects/`), así que conviven varias síntesis por semana sin `split:`. Tras escribir: `git add` + `commit` (`docs(sintesis): <reunión> <fecha>`) + `push`.

**En la primera prueba: mostrá el doc y esperá el OK de César antes de commitear.**

## Fuera de alcance (follow-ups)

- **Red de Gemini activa** — cross-check del verbatim contra las "Notas de Gemini" para levantar candidatos a confirmar. v1.1; requiere que `transcripcion.py` exponga la pestaña resumen (hoy solo emite la de Transcripción).
- **Ritual semanal push** — índice `00-semana.md` con wikilinks + scheduler LOCAL los lunes que te trae las síntesis de la semana. Fase 2.
- **Triaje semanal inteligente** — priorizar y consolidar entre reuniones. Fase 2.
