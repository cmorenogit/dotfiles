---
name: linear-lore
description: Entiende un issue de Linear y su situación en lenguaje claro — lee el issue + todo el hilo + los PRs asociados y devuelve de qué se trata (para cualquiera), qué se decidió y qué falta, quién espera qué, y de qué tipo es (review / duda técnica / decisión de producto / mención). Si hay algo que responder, sugiere /linear-respond. Triggers — "/linear-lore <ID>", "entendé <ID>", "qué onda con <ID>", "de qué va <ID>", "ponme al día con <ID>". NO postea ni decide.
---

# linear-lore — entender un issue

Resuelve "no entendí qué pasaba". El deliverable es la **comprensión**, no una respuesta. No postea, no decide, no redacta el comentario (eso es `/linear-respond`).

**Input:** `<ISSUE-ID>` (ej. RYR-132).

## Flujo

1. **Leé la realidad completa.**
   - Issue: descripción (`get_issue`) **y** TODOS los comentarios en orden (`list_comments` por `createdAt`, paginado hasta el final). `read_linear_issue` trunca threads largos — no lo uses como única fuente del "último comentario".
   - PRs asociados: los que el issue o el hilo referencien (`gh pr view` para contexto, sin checkout).
   - Threads largos (80+ comentarios): delegá la lectura a un sub-agente que devuelva `{comentario más reciente, decisiones cerradas, quién espera qué, citas verbatim + comment_id}`.
2. **📖 De qué se trata** — el problema en lenguaje súper simple, para alguien que NO conoce el issue (2-3 frases, cero jerga). Esto es lo principal: que cualquiera entienda en 5 segundos.
3. **Situación** — leé el flujo: qué se decidió, qué avanzó, qué está pendiente, **quién espera qué** (de César o de otro). Si alguien ya cerró el punto o la conversación avanzó sin esperar a César → decílo (no todo lo que lo menciona necesita su acción).
4. **Tipo** — clasificá de qué se trata (apoyate en el skill `lane` para saber si le toca a César o es de otro):
   - **review** — un dev pide revisar un PR (lane de César).
   - **duda técnica / consulta** — "¿qué plan elijo?", una opinión (lane de César).
   - **decisión de producto** — alcance, priorización (NO es lane de César → se rutea a Nicole/Ignacio).
   - **mención / acuse** — FYI o ya cerrado.
5. **Cierre** — si hay algo que César deba responder → **sugerí `/linear-respond <ID>`** nombrando el tipo detectado (así respond arranca con el insumo). Si ya está cerrado o no le toca → decílo, sin acción.

## Reglas

- **Cita-o-no-existe:** todo lo que afirmes del hilo lleva su cita verbatim + `comment_id`. Si no aparece en la fuente, no lo afirmes.
- **No inventes el estado del código.** Si la situación depende de un hecho de código, marcalo como *a verificar* (eso lo hacen `verificacion`/`respond`), no lo asumas.
- **No postea, no redacta la respuesta, no decide.** Solo entender.
