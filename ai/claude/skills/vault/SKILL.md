---
name: vault
description: Consolidá un documento en el vault (~/Code/_vault) — guardar = EXTENDER el doc del tema, no crear otro archivo. Clasifica, rutea según el mapa, consolida por type, versiona con git (no con nombres) y hace commit + push. Triggers: "guardá esto en el vault/baúl", "consolidá esto", "persistí este doc", "/vault", y SIEMPRE antes de persistir un documento bajo ~/Code/_vault.
---

# vault — consolidar en el cerebro único

Principio: guardar = **consolidar**, no verter. El default es **extender** el doc del tema; crear archivo nuevo es la excepción que hay que justificar. Así se evita el sediment (`00-05`, `FINAL`, `v3/v4`, links rotos).

## Flujo (orden estricto)

1. **Leer el mapa:** `~/Code/_vault/CLAUDE.md` (ruteo + formato + enum de `type`). Es la fuente de verdad; esta skill no la duplica.

2. **Resolver TEMA + `type`:**
   - **Tema** = el issue (`RYR-119` → `projects/rr/issues/RYR-119/`, proyecto por prefijo) o el workstream. Crear la carpeta del tema si no existe.
   - **`type`** = un valor del **enum cerrado** del mapa (`analisis | propuesta | plan | review | investigacion | postmortem | nota | referencia`). **No inventes un type.** Si no encaja en ninguno, es `nota` — o el tema está mal definido.

3. **Buscar antes de crear (el corazón):** ¿ya hay un doc de ese `type` en la carpeta del tema?
   - **Sí → consolidá ahí.** Append **no-destructivo**: integrá el contenido, nunca sobreescribas perdiendo (git es la red).
   - **No → creá.** Es el primer doc de ese type.
   - **¿Hay un doc del mismo type pero creés que esto es distinto?** Pregunta-test: *"si junto los dos en un archivo, ¿queda coherente o un revoltijo?"*. **Coherente** → era el mismo material, consolidá. **Revoltijo** → es contenido genuinamente distinto: declará el escape (`split: <razón>` en el frontmatter) y creá. El eje que justifica partir es **el contenido**, nunca la persona ni la fase.

4. **Release-valve de tamaño:** si el doc consolidado supera ~500–800 líneas → partí por **sub-tema** (con `split:`), nunca por fase ni versión.

5. **Nombre + frontmatter** según el mapa. **Nunca** sufijos de versión/estado en el nombre (`-v2`, `-v3`, `-final`, `CONSOLIDADO`, `-fase1`) — git versiona. Snapshot con propósito = `nombre-YYYY-MM-DD-razon` (acto deliberado, no número incremental).

6. **Index note:** si la carpeta-tema queda con **≥3 docs**, mantené su MOC (`00-modulo.md` si ya existe; si no, `00-index.md`): `[[wikilink]]` + H1 como glosa, regenerado escaneando la carpeta. No aplica a **colecciones** (`linkedin/posts/`, `transcripts/`, `linear/today/`), donde un-archivo-por-entidad es correcto.

7. **Commit + push** — el doc **y su index** (si se tocó), solo lo de este guardado:
   ```bash
   cd ~/Code/_vault && git add <archivos> && git commit -m "docs(<scope>): <qué>" && git pull --rebase && git push
   ```
   `<scope>` = team del issue (ej. `ryr`) o slug del proyecto. Push fallido → resolver y reintentar; un guardado sin push no está terminado.

8. **Informar:** ruta final + hash del commit, en una línea.

## Modo triar (a demanda — limpiar sediment existente)

Cuando una carpeta ya acumuló sediment (varios archivos fragmentados / versionados por nombre), **no consolides a ciegas — triá** cada archivo a uno de tres destinos, **supervisado** (proponé el mapeo completo, César revisa, recién ahí ejecutás):

- **Archivar → `_archive/`** lo superado o muerto (versiones viejas, capas reemplazadas por una nueva).
- **Consolidar** lo vivo fragmentado, por `type`.
- **Reubicar** lo mal-puesto (workstream que en realidad es de un issue → `issues/<ID>/`).

git preserva todo; append no-destructivo. No tocar un tema **vivo y en curso** en medio del trabajo — triar en un punto de cierre.

## Reglas duras

- Nunca escribir en la raíz del vault.
- Default = **consolidar**; archivo nuevo = excepción justificada **por contenido** (no por fase, versión ni persona).
- `type` siempre del **enum cerrado** — no inventar types (es la causa raíz de la fragmentación).
- **git versiona, no los nombres.**
- No commitear archivos ajenos a este guardado: el vault suele tener trabajo en curso de otros flujos.
