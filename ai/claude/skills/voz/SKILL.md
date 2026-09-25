---
name: voz
description: Da voz humana a una respuesta de Linear antes de mostrarla — español mexicano neutral, claro y no extenso, con @mención al destinatario al inicio y lo denso (reportes, logs, tablas largas) envuelto en bloques de código. Úsalo al redactar cualquier comentario para Linear o cuando otro skill necesita formatear un borrador para publicar. NUNCA postea — devuelve el borrador para que César revise.
---

# voz — respuesta de Linear con voz humana

Toma el contenido de una respuesta y lo deja listo para pegar en Linear: que se entienda rápido, suene a persona y respete la forma. NO decide el contenido ni postea.

## Reglas de forma

1. **Abrí con la @mención** del destinatario (`@samuel`, según a quién se responde).
2. **Español mexicano neutral, humano** — "tú", sin localismos de ninguna región, sin sonar robótico ni telegráfico. Como lo escribiría un colega competente.
3. **Corto y claro.** Liderá con lo esencial (la respuesta o el veredicto); el contexto, después y solo si ayuda a entender.
4. **Técnico solo si la situación lo amerita.** Si el punto se entiende sin el detalle técnico, omitilo.
5. **Lo denso va en bloque de código.** Un reporte de pr-review, logs, una tabla larga o un diff → dentro de un bloque ``` para que no ahogue el mensaje.
6. **Mostrá el borrador para revisión.** NUNCA postees — César publica.
7. **Sin huecos en el bloque copiable.** Si al texto le falta un dato (un valor que no tenés, un campo a completar), NO lo entregues en bloque listo para copiar — eso invita a publicar el hueco. Marcá el borrador como **incompleto**, nombrá qué falta, y el bloque limpio sale recién cuando está entero.
8. **Antes de redactar, re-medí** (sep-2026: ~70 correcciones de César por borradores con datos viejos o falsos): re-leé el hilo desde el último comentario que viste (`list_comments`), hacé `git fetch` de las ramas que citás, y armá al PIE del borrador (fuera del bloque copiable) una tabla `afirmación → comando/fuente`. Una cifra sin fila en esa tabla no entra.
9. **Una publicación = un comentario.** Si el issue tiene un veredicto o pedido abierto (de Ignacio, Hakeem, Nicole), la respuesta va como **reply** a ese comentario (`parentId`), no como comentario nuevo de primer nivel.
10. **Lo que nunca va en el texto**: rutas locales, la bitácora, engram o el vault (son memoria personal y confunden); ofrecer "si quieres lo hago yo"; "sin merge hasta tu OK" u otras menciones a mergear (César no mergea: lo hace Hakeem). El `cc` va al final. Cada ID citado es del hilo o se marca "(relacionado)".
11. **Tope**: ≤12 líneas fuera de los bloques de código. Si no entra, lo que sobra es contexto que no hace falta.
12. **Plantilla según el momento** (la define el precedente del issue o del padre): primera solicitud → Plantilla A del `CLAUDE.local.md` del worktree; iteración tras un veredicto → reply con las condiciones cerradas y la evidencia nueva; cierre → Plantilla D.

## Salida

El borrador formateado, en bloque para copiar, + una línea de qué ajustaste (si algo). Si el texto ya estaba bien, devolvelo igual y decílo.
