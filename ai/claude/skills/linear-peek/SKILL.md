---
name: linear-peek
description: Vistazo rápido a UN issue de Linear — vuelca los comentarios de una ventana de tiempo (default HOY) verbatim, cuerpo completo, con fecha en GMT-5, para ponerte al día sin el análisis pesado de lore. Triggers — "/linear-peek <ID>", "qué se habló hoy en <ID>", "comentarios de <ID>", "ponme al día rápido con <ID>".
---

# linear-peek — el hilo de un issue por ventana de tiempo, crudo

Corré el script con el ID y mostrá su salida **tal cual**. Ya viene formateada, en GMT-5, verbatim. No la resumas, no la interpretes, no la reordenes — el script es la fuente determinista; vos solo lo disparás.

```sh
bash ~/.claude/skills/linear-peek/peek.sh <ID>        # lo de HOY (default)
bash ~/.claude/skills/linear-peek/peek.sh <ID> 3d     # últimos 3 días  (también 12h, 7d…)
bash ~/.claude/skills/linear-peek/peek.sh <ID> all    # el hilo completo
```

Reenviá el ID (y la ventana si la dio) tal como los pasó el usuario. La ventana es opcional: `(vacío)`=hoy · `Nd` · `Nh` · `all`.

## Qué es — y qué no

*peek* = **entrar a un issue y leer lo que se habló en una ventana de tiempo**, nada más. Vuelca contexto (estado · responsable · URL · descripción breve) + el **cuerpo completo** de cada comentario de la ventana, con su fecha. Cronológico (viejo → nuevo); el último va marcado `← más reciente`; los replies con `↳`. Si la ventana queda vacía, te muestra el último que hubo y cómo ampliar.

- **Verbatim, no interpretado.** peek no analiza ni decide — te muestra el texto para que *vos* entiendas. La fecha de cada comentario está a la vista justamente para no darte falsa sensación de estar al día.
- **Orden propio, no el de Linear.** La connection `comments` de Linear viene por `updatedAt`; peek la reordena por `createdAt` para que el orden sea el real de la conversación y no se pierda lo nuevo.
- **Determinista y barato** (una query, sin LLM) — como `/linear-scan`, pero de un issue en vez del inbox.

Si tras leerlo querés que alguien lo **mastique** (de qué se trata, qué se decidió, qué falta, quién espera qué) → `/linear-lore <ID>`. Si querés **responder** → `/linear-respond <ID>`.

## Lugar en el flujo

```
/linear-scan         qué se movió (inbox, sin contenido)
   └─ /linear-peek <ID>    leer rápido el hilo reciente de uno   ← este
        └─ /linear-lore <ID>     entenderlo a fondo (análisis)
             └─ /linear-respond <ID>   redactar la respuesta
```
