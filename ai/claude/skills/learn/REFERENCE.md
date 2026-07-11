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
url: "https://…"             # opcional — se omite en modo paste
type: youtube | twitter | web | tiktok | instagram | paste   # la fuente; paste = contenido pegado sin origen
author: "Canal / @handle / autor"   # opcional — se omite si no se identifica
date: 2026-06-14             # publicación de la fuente; se omite si no se conoce (modo paste)
processed: 2026-06-21        # descarga (hoy) — y es la fecha del NOMBRE del archivo
duration_min: 74             # solo audio/video; omitir si no aplica
status: pending
tags: [tema, tema]           # 3-7, kebab, inglés salvo nombres propios
related: ["[[…]]", "[[…]]"]
---
```

**Nombre del archivo:** `<processed>-<slug>.md` — la fecha es la de **descarga** (hoy), no la de publicación. Así las notas se ordenan por cuándo las consumiste, no por cuándo se publicó el contenido.

**Modo paste** (contenido pegado, sin URL): `type: paste`, carpeta `learning/paste/`. `url`, `author` y `date` se **omiten** si no se identifican (no inventes). La sección Fuente declara que vino pegado, así el lector sabe que no hay fuente verificable.

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
## Cómo replicarlo     · SOLO si la fuente muestra un procedimiento (tutorial,
                         demo, setup): pasos y comandos exactos en orden,
                         seguibles SIN ver el video; si hay `chapters`,
                         referenciá el minuto de cada paso (ej. "min 4.2")
## Recursos            · links de la `description` que importan (repo, docs,
                         herramienta) + herramientas nombradas, cada una con
                         una línea de qué es. SOLO lo que la fuente referencia
                         — nunca inventes URLs; omití sponsors/afiliados salvo
                         que sean la herramienta del video
## Puntos clave        · ideas accionables (la mayoría de fuentes)
## Datos clave         · tabla | dato | valor | fuente | (cuando hay cifras)
## <Secciones por tema/módulo>  · fuentes largas (cursos, charlas)
## Citas               · textuales que valga la pena guardar

## Lectura crítica
⚠️ claims a verificar (cuando la fuente afirma) + conexión a tu stack (siempre).

## Aplicación
1-3 acciones concretas, en imperativo, de qué hacer con esto (probar X,
replicar Y, descartar porque Z) — es lo primero que se lee al revisar
la cola de `status: pending`.

## Relacionado
- [[wikilink]] — por qué se conecta

## Fuente
- [{tipo}]({url}) · {author} · {duration_min} min     # o, en paste: "Contenido pegado, sin URL ni autor identificado."
```

**Profundidad proporcional a la fuente:** un tweet usa TL;DR + Resumen + Puntos clave; un curso de 6 h despliega secciones por módulo. No fuerces secciones vacías — "Cómo replicarlo" solo existe si hay procedimiento; "Recursos" solo si la fuente referencia links o herramientas.

## Voz (inspirada en `voz`, sin acoplar)

- Español **neutral, claro, humano** — se lee de corrido.
- **Sin** `@mención` ni formato de comentario Linear (eso es de `voz`, no de acá).
- Lo denso (logs, código, tablas largas de la fuente) va en bloques de código.
- Primera persona al conectar con tu stack; nunca telegráfico ni jerga de máquina.
