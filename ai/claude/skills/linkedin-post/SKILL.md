---
name: linkedin-post
description: >
  Fábrica de posts de LinkedIn para la marca personal de César (AI Product Engineer). Full-auto:
  das un TEMA (texto o ruta a nota del vault) o una EXPERIENCIA tuya, y produce el post listo para
  publicar + el prompt de imagen, con dos gates de calidad (entrada y salida). Voz neutra, estilo
  didáctico, lente IA×producto IMPLÍCITO. NUNCA publica sin tu OK. Triggers: "/linkedin-post",
  "armá un post de <tema>", "post de LinkedIn sobre <X>", "hacé un post con esta nota".
---

# linkedin-post — fábrica de contenido (full-auto, doble gate)

Principio rector: el valor no está en la mecánica (research, redacción — eso se commoditiza) sino en los **dos gates de criterio**. El de entrada evita gastar en un tema que no sirve; el de salida evita publicar mediocridad. Sin gates, esto es una máquina de "AI slop" — lo que el algoritmo suprime y lo que destruye autoridad. La fábrica **produce**; **César aprueba y publica con su OK**.

## Contexto (fuente de verdad del posicionamiento)

Outcome, audiencia, diferenciador y constraints viven en `~/Code/_vault/_personal/projects/app-profile/` (discovery del sistema de marca). En una línea: LinkedIn construye **autoridad profesional ante empresas** (NO captación freelance — eso es la web), proyectando **"AI Product Engineer"** = quien sabe QUÉ construir con IA porque piensa desde el producto. Tono aporte, no-pitch. **Discreción dura** frente a Apprecio.

## Input

`/linkedin-post <tema | ruta a nota del vault | "experiencia: <tu caso>">`

- **Modo tema** (default) — un concepto/tendencia → research + análisis. Las notas de César suelen estar en `_personal/learning/`.
- **Modo experiencia** — César aporta un caso/vivencia propia → SIN research; el valor es su experiencia (tier-1, el oro). Salta la fase 2.

## Flujo (full-auto — César solo interviene en el output)

### 1 · GATE DE ENTRADA — ¿vale la pena? (antes de gastar research)

Evaluar el tema contra 3 criterios:
- **Ángulo genuino** — ¿hay un cruce IA × producto real, no forzado? Si solo da para IA técnica pura o producto puro, no es para este perfil.
- **No-obvio** — ¿aporta algo más allá del hype/buzzword/obviedad?
- **Discreción** — ¿se puede tratar sin exponer Apprecio?

Veredicto: **✅ sigo** · **⚠️ sigo con reencuadre** (decir cuál) · **❌ descartar** → "este tema no es adecuado porque {razón}. Buscá otro, o reencuadralo así {sugerencia}". Fail-closed — ante la duda NO inflar, pedir otro tema.

### 2 · RESEARCH (solo modo tema)

Sub-agente (Task/Agent, web profundo). Objetivo: el concepto al máximo nivel + dónde el cruce IA×producto es **genuino** + la crítica/matices (para no escribir hype) + prueba citable. Devuelve síntesis + fuentes + veredicto del ángulo.

### 3 · REDACCIÓN

Aplicar TODAS las reglas (abajo). Modo experiencia: la historia de César es el centro, sin research.

### 4 · GATE DE SALIDA — ¿lo que salió es bueno? (fail-closed)

**Evaluador independiente — Claude** — un sub-agente vía Task/Agent que recibe SOLO el post + la rúbrica + las fuentes (para verificar anti-alucinación), NUNCA cómo se escribió, y lo juzga contra la rúbrica dura de abajo.

> **Nota (jun 2026):** el segundo evaluador cross-model (GPT-5.5 vía `pi`) se retiró al eliminar `cross-validate` — es otro concepto de verificación. Hoy queda el gate de un solo evaluador; la verificación de linkedin-post se revisa aparte cuando se retome el sistema de marca personal.

**Reconciliación — fail-closed:** publicable SOLO si el evaluador da ✅. Si marca un bloqueante (alucinación · AI-slop · ángulo forzado · no-obvio · discreción) → fail → **1 reintento** de redacción con el feedback → re-evaluar. Si tras el reintento sigue fallando → **escalar a César** "de este tema no salió nada a tu altura. Descartá o pasame más material." **No bajar el umbral para forzar un pase.**

### 5 · PROMPT DE IMAGEN — infografía estilo "ML TUT"

El estilo de César es una **INFOGRAFÍA EDUCATIVA de una sola página** — sketchnote hecho a mano pero profesional/premium — **NO un diagrama minimalista**. El prompt debe convertir el post en una infografía:
- **Título handdrawn** (marcador, grande) + subtítulo de una línea.
- **5-7 bloques numerados** (círculo azul con número), cada uno con un **icono dibujado a mano** + una **frase corta** (palabras clave, no oraciones largas).
- **Flujos con flechas** donde aplique (ej. find → execute → evaluate → repeat).
- Un bloque **"IDEA CLAVE"** destacado al cierre.
- **Destacar visualmente** el bloque del insight central (glow/color).
- **Paleta con propósito**: azul = títulos · verde = conceptos clave · naranja = advertencias · morado = ejemplos · amarillo = ideas importantes.
- Fondo blanco, mucho espacio, estilo limpio/manual/premium, formato **vertical**.
- **Pie de marca** (en TODA infografía — **SUTIL, esto es clave**): una sola línea al pie, en **letra pequeña y color tenue/gris**, que firma sin gritar. Contiene **`Cesar Moreno · cesarmoreno.dev`** (la URL viaja con la imagen al destino del funnel) + en **modo tema** **`Fuente: {fuente}`** (credibilidad). **NUNCA** mayúsculas grandes, flechas llamativas, logos prominentes ni nada que compita con el contenido. Es una firma discreta, no publicidad — el contenido manda, la marca solo acompaña al pie.
- **NO meter `Creado con IA` en el footer de la imagen.** Verificado — los generadores renderizan mal el texto pequeño, sobre todo el acrónimo (sale `Creado con Ia`, `lA`, etc.) y eso se ve poco profesional. La **transparencia de IA va por otro canal**, donde el texto se controla y se escribe bien — una línea al final del **caption del post** (`Imagen creada con IA.`) o la **etiqueta nativa de LinkedIn** (Content Credentials / C2PA). El footer de la imagen solo lleva nombre · URL · fuente. Mantener el texto del footer en **palabras comunes** (nombre, dominio, fuente) que el generador sí renderiza bien; evitar acrónimos y símbolos raros.

El prompt **especifica el contenido exacto de cada bloque** (texto corto), sujeto al mismo check anti-alucinación. César corre la imagen en su agente (que ya tiene el estilo cargado).

### 6 · OUTPUT + PUBLICACIÓN

Presentar: **texto del post** (en bloque) + **prompt de imagen** + nota de ángulo/fuentes + estado del gate (✅).
Publicación **NO automática** — César corre la imagen y da OK del contenido final; recién ahí se publica vía chrome-devtools (sesión LinkedIn logueada). Verificar el estado del navegador antes. Recordar la línea de transparencia en el caption (`Imagen creada con IA.`). Registrar el post en **`_personal/projects/linkedin/posts/`** (canal LinkedIn, NO `app-profile/` que es la web) — `YYYY-MM-DD-<slug>.md` con tema/ángulo, texto, prompt de imagen, fuentes, estado de gates, **la URL del post** y un slot de métricas (impresiones · comentarios · visitas al perfil · outcome) para llenar a ~7 días.
- **Tras publicar, PEDIR a César la URL del post** y guardarla en el frontmatter (`url:`) del registro. Es obligatorio — sin la URL no se pueden atar las métricas ni detectar temas duplicados, y es lo que ancla el loop de aprendizaje (qué tema/ángulo mueve el outcome).

## Reglas de redacción (codificadas — no se renegocian por post)

**Voz e idioma**
- Español **NEUTRO internacional**. "tú", nunca "vos". Sin localismos (de ningún lado). Sin palabras rebuscadas. Sin spanglish evitable (preferir "darle instrucciones" a "promptear", salvo término técnico sin equivalente como "loop", "agente", "prompt").
- **SIN dos puntos (`:`)** — reemplazar por frases directas, punto, o guion largo (—). César los siente poco naturales.
- Estilo **DIDÁCTICO** — enseña, no juzga. NUNCA el tono contrarian "todos hacen X mal".

**Estructura (plantilla base — variar entre posts para no clonar)**
1. **Apertura** — presenta el tema, por qué vale la pena entenderlo. Hook <12 palabras (tensión/curiosidad/observación, NO juicio).
2. **La idea/mecánica** — explica el concepto claro.
3. **El giro** — el insight no-obvio (acá vive el valor).
4. **Cierre en AFIRMACIÓN** potente (no pregunta) — la tesis con el lente IA×producto IMPLÍCITO.

**El lente (lo más importante)** — mostrar el criterio, NUNCA etiquetarlo. Prohibido escribir "criterio de producto", "decisión de producto", "como product manager". El lector debe SENTIR que este pensó *para qué sirve* la IA, sin que se lo digan. Si no se puede integrar natural, el tema no era el adecuado (era trabajo del gate de entrada).

**Formato**
- 200-280 palabras. Saltos de línea generosos (70% lee en mobile). ≤2 hashtags temáticos. ≤1 emoji (0 = más autoridad).
- Texto plano por defecto. Carrusel solo si el insight es un framework o caso con pasos.
- Prueba **tier 1-3** (experiencia/data/observación de César) > tier 4 (stats prestadas). El oro es lo que solo César puede decir.

## Rúbrica del GATE DE SALIDA (el evaluador independiente verifica cada ítem)

- [ ] El ángulo IA×producto se siente **genuino**, no forzado ni etiquetado.
- [ ] Hay un **insight no-obvio** (no hype, no obviedad, no lista de buzzwords).
- [ ] El **hook** engancha en <12 palabras, sin juzgar.
- [ ] Voz neutra, "tú", sin localismos, **sin dos puntos**, didáctica, cierre-afirmación.
- [ ] El lente está **implícito** — las palabras "producto/criterio" NO aparecen.
- [ ] Respeta la **discreción** (no expone Apprecio).
- [ ] **Sin alucinaciones (precisión factual)** — todo nombre propio, cargo, atribución, cita, dato, herramienta o afirmación factual EXISTE y está citado correctamente. Verificar contra el research/fuentes. Si algo no se puede verificar, NO afirmarlo (reformular a algo defendible o quitarlo). Atribuir mal una cita, inventar un nombre o un cargo equivocado destruye la autoridad al instante.
- [ ] **No suena a "AI slop"** — tiene voz y punto de vista; algo que la IA genérica no diría.
- [ ] 200-280 palabras, ≤2 hashtags, ≤1 emoji.

Cualquier ❌ en genuino / no-obvio / AI-slop / discreción / **alucinación** = **fail** (no es cosmético). El gate puede y DEBE rechazar — si en muchos posts nunca rechaza, la rúbrica está rota.

## Guardrails

- **Full-auto hasta el output, NUNCA hasta la publicación.** César aprueba el contenido final y corre la imagen; recién ahí se publica con su OK.
- El gate de salida es **independiente y fail-closed** — sub-agente fresco, no auto-revisión. Umbral real.
- **No bajar el umbral para forzar un pase.** Mejor escalar "este tema no rindió" que publicar mediocridad.
- La fábrica cubre dos pilares — "comentario con lente" (modo tema) y "experiencia" (modo experiencia). **Empujá el modo experiencia cuando el tema lo permita** — la experiencia de César es el oro; comentar temas de otros es tier-4.
- **Variar la estructura** entre posts — la sameness es "AI slop".
- **Discreción Apprecio** — capacidad/aprendizaje sí, IP/artefacto interno no.
