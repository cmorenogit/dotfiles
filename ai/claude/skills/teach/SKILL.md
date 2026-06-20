---
name: teach
description: >
  Enseña CUALQUIER tema (producto, RLS, una librería, lo que sea) en lecciones HTML interactivas,
  pre-validado contra fuentes confiables (nunca de memoria). Dos modos según el tema tenga plan o no:
  ad-hoc (one-shot) o curso (recorre el plan en orden y se acopla a /study). Te enseña y te evalúa,
  pero la ficha la escribís vos. Triggers: "/teach <tema>", "enseñame <X>", "quiero aprender <X>".
disable-model-invocation: true
---

# teach — adquisición ordenada y pre-validada

Principio rector: **enseña anclado a la fuente, nunca de memoria.** Cada afirmación clave se cita; lo no-verificable se marca. El agente enseña y te evalúa (priming, checkpoints) — pero **la ficha la escribís vos**. Si te la da masticada, consumís y no retenés (el modo de falla #1, igual que `/study`).

## Modo (detectar y declarar al arrancar)

Detección: ¿existe `_personal/learning/teach/<tema>/plan-*.md`?

| Modo | Cuándo | Qué hace |
|---|---|---|
| **Curso** | hay plan (ej. `producto`, `ingles`) | recorre el plan **en orden** (sección que toca); al cerrar, fichás → `/study` refuerza |
| **Ad-hoc** | no hay plan (ej. `/teach RLS`) | enseña el tema **one-shot**; deja la lección en la carpeta; `/study` no entra hasta que el tema tenga plan |

**Anunciá el modo en una línea antes de empezar** ("no hay plan para 'RLS' → modo ad-hoc"). Crear la carpeta del tema `_personal/learning/teach/<tema>/` si no existe (workspace persistente — enfoque de Matt).

## Fuente (pre-validación — genérica, NO cableada a producto)

Ancla cada afirmación clave a una fuente, eligiéndola por el tema:

| Tema | Fuente primaria |
|---|---|
| curso con libro | **el libro** (la sección que toca) |
| producto | `_work/apprecio/_shared/product-decision-canon.md` + el libro |
| técnico (RLS, una librería) | **context7** (docs oficiales) + web |
| crítico / dudoso | + `cross-validate` (otro modelo) |

- **Citá verbatim** lo decisivo. Lo que no podés verificar → marcalo *"interpretación, verificá"*, **no lo enseñes como hecho**.
- **Validación proporcional al riesgo:** un matiz que mal aplicado te lleva a una decisión equivocada → validación fuerte; lo trivial, liviano.
- **Si las fuentes difieren → marcalo** (tension-check), nunca aplanes.

## Flujo de una sesión

1. **Contexto.** Modo curso: leer plan + tracker + **misión** → la sección que toca. Ad-hoc: el tema del argumento.
2. **Priming.** 2-3 preguntas/hipótesis sobre la sección **antes** de enseñar — respondés desde lo que ya sabés. No revelar aún.
3. **Enseñar (HTML pre-validado).** Generar la lección en `lessons/NNNN-<slug>.html` — la sección en orden, **cada bloque citado** a su fuente, lo no-verificable marcado. Contrastar con lo que respondiste en el priming.
4. **Checkpoints.** La lección lleva preguntas interactivas con feedback (retrieval, no texto para releer). Si fallás un punto → re-explicá **antes** de seguir construyendo encima.
5. **Cierre.** Listar los **1-3 conceptos** que ameritan ficha — **NO escribirlas**: *"tu turno: escribí la ficha de [X] → después `/study` la refuerza"*. Modo curso: avanzar el tracker.
6. **Commit + push** (carpeta del tema; regla cero del vault) y abrir la lección (`open`).

## Formato del HTML (lo que lo salva de ser "lindo pero inútil")

- **Uno por sección:** `_personal/learning/teach/<tema>/lessons/NNNN-<slug>.html` (colección — un archivo por sección).
- **Interactivo:** checkpoints embebidos (preguntas con feedback) — retrieval activo, **no** un texto para releer pasivo (releer = *fluency*, no *storage*).
- **Citado:** cada afirmación clave linkea/cita su fuente — la lección es un **mapa hacia el libro**, no un reemplazo.
- **`assets/` compartido:** un stylesheet común para todas las lecciones (consistencia; no regenerar CSS por lección).
- **No reemplaza tu ficha:** cierra con el slot *"tu turno: ficha de [X]"*, no la escribe.

## Enlace con `/study`

La carpeta del tema es un **workspace compartido**: `/teach` llena `lessons/` + `assets/`; `/study` opera cuando hay `plan-*.md` + `fichas/`. Volver un tema ad-hoc en curso = agregarle plan + empezar a fichar (la carpeta **ya existe**, no se mueve nada). `/study` **ignora** las carpetas sin plan, así que las lecciones ad-hoc no le hacen ruido.

## Guardrails

- **Nunca enseñar de memoria** — cada afirmación clave anclada a fuente; lo no-verificable se marca.
- **Nunca escribir la ficha por César** — evaluarlo sí (priming, checkpoints, quiz), redactar su apunte no.
- **La fuente es la autoridad**, la lección es el mapa hacia ella — no el reemplazo.
- **Genérico:** enseña cualquier tema; la jerarquía de fuentes se adapta, no está cableada a producto.
