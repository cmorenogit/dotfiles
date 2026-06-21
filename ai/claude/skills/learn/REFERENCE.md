---
name: learn-reference
description: Molde de nota, schema de frontmatter y reglas de voz para /learn. Disclosed desde SKILL.md.
disable-model-invocation: true
---

# Referencia de /learn — molde, schema, voz

## Frontmatter estándar

Unificado para todas las fuentes. Mantiene `type` = la fuente (como el corpus existente), no `source`, para no fragmentar queries.

```yaml
---
title: "Título legible de la fuente"
url: "https://…"
type: youtube | tweet | web | tiktok      # la fuente
author: "Canal / @handle / autor"
date: 2026-06-14              # publicación de la fuente
processed: 2026-06-21         # descarga (hoy) — y es la fecha del NOMBRE del archivo
duration_min: 74              # solo audio/video; omitir si no aplica
status: pending
tags: [tema, tema]            # 3-7, kebab, inglés salvo nombres propios
related: ["[[…]]", "[[…]]"]
---
```

**Nombre del archivo:** `<processed>-<slug>.md` — la fecha es la de **descarga** (hoy), no la de publicación. Así las notas se ordenan por cuándo las consumiste, no por cuándo se publicó el contenido.

## Molde de la nota

Núcleo **fijo** (siempre, en este orden) + cuerpo **adaptativo** entre Resumen y Lectura crítica. La nota es el **único artefacto** (no se guarda transcripción), así que debe ser auto-suficiente.

```
# {título}

## TL;DR
3-5 líneas. El gancho: qué es, por qué importa, el veredicto.

## Resumen
Consolidación auto-suficiente: leés esto y entendés todo lo importante.
Prosa humanizada, no bullets sueltos.

<CUERPO ADAPTATIVO — elegí según densidad>
## Puntos clave        · ideas accionables (la mayoría de fuentes)
## Datos clave         · tabla | dato | valor | fuente | (cuando hay cifras)
## <Secciones por tema/módulo>  · fuentes largas (cursos, charlas)
## Citas               · textuales que valga la pena guardar

## Lectura crítica
⚠️ claims a verificar (cuando la fuente afirma) + conexión a tu stack (siempre).

## Relacionado
- [[wikilink]] — por qué se conecta

## Fuente
- [{tipo}]({url}) · {author} · {duration_min} min
```

**Profundidad proporcional a la fuente:** un tweet usa TL;DR + Resumen + Puntos clave; un curso de 6 h despliega secciones por módulo. No fuerces secciones vacías.

## Voz (inspirada en `voz`, sin acoplar)

- Español **neutral, claro, humano** — se lee de corrido.
- **Sin** `@mención` ni formato de comentario Linear (eso es de `voz`, no de acá).
- Lo denso (logs, código, tablas largas de la fuente) va en bloques de código.
- Primera persona al conectar con tu stack; nunca telegráfico ni jerga de máquina.
