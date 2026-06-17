---
name: linear-voice
description: >
  Pule un texto suelto para publicarlo en Linear con voz humana — español mexicano neutral, profesional,
  que suene a persona y no a máquina. Es un ATAJO para comentarios directos (ya tenés el texto, no querés
  el pipeline de review): corre el gate compartido en perfil FORMA, sin re-implementar nada. NUNCA postea.
  Para responder/revisar un issue de fondo, ese es /linear-respond. Triggers: "/linear-voice", "pulí este
  comentario", "que esto suene humano", "revisá la voz de esto antes de publicar".
---

# Linear Voice — pulir la voz de un comentario (perfil FORMA del gate)

Lee el contrato: `~/.claude/skills/_shared/linear-contract.md` (B2 · Gate y **Perfiles del gate**). Este skill **no define criterios** — corre el gate compartido en **perfil forma**. Si mañana se agrega un criterio de forma al §3.5, este comando lo hereda solo.

**Qué es y qué NO es:**
- **Es:** el atajo para un texto YA escrito que vas a pegar como comentario directo, cuando solo querés que **suene humano y bien dicho** antes de publicarlo.
- **NO es:** el flujo de responder/revisar un issue. Eso es `/linear-respond` (perfil completo: pertinencia + calidad + credibilidad, con el contexto del hilo). `voice` no tiene contexto de issue y no lo finge.

**Input:** `<texto>` inline (el borrador del comentario). Opcional: el `ISSUE-ID` solo como referencia de tono, no se lee el hilo.

## Flujo

1. **Correr el gate en perfil FORMA** (los criterios autocontenidos del filtro CALIDAD — hoy **6 estilo** + **10 voz humana**; ver §3.5 del triaje). Dos anillos:
   - **Anillo 1** (Claude) — evaluá el texto contra los criterios de forma: ¿confiado y lean sin ser seco? ¿español mexicano neutral, sin localismos de ninguna región? ¿suena a una persona competente, no a máquina? ¿claro y entendible?
   - **Anillo 2** (`pi`/gpt-5.5) — segundo modelo, porque un solo linaje no detecta sus propios localismos ni su propio "tono robot". Prompt ACOTADO (patrón de `linkedin-post` §4):
     ```bash
     timeout 120 pi -p --provider openai --no-tools "<prompt acotado>"   # NO pasar --model (usa gpt-5.5 por suscripción)
     ```
     El prompt lleva: rol (revisor de tono para comentarios de trabajo en Linear) + el check corto ("¿español mexicano neutral, profesional y humano —no robótico, no telegráfico—, sin localismos?") + el texto + "responde SOLO PUBLICABLE/AJUSTES y qué cambiarías, máx 4 líneas".
   - **Consenso fail-closed:** si cualquier anillo marca un problema → reescribí el texto y re-evaluá (≤2 vueltas). Ante discrepancia, gana el criterio más estricto.

2. **Devolver:** el **texto pulido** (en bloque, listo para copiar) + una línea de **qué cambió y por qué** (localismos, frases robóticas, claridad). Si el texto ya estaba bien → devolvelo igual y decilo.

3. **Frontera — derivar si hace falta.** Si al leer el texto detectás que necesita **juicio de fondo** (afirma un claim de código sin verificar → Criterio 5; toca una decisión que podría estar cerrada → Criterio 8; decide algo del lane de Julieth/Nicole → Criterio 4), **no lo resuelvas acá**: avisá "esto amerita `/linear-respond <ISSUE>` — {por qué}", porque eso requiere el contexto del hilo que `voice` no carga.

## Reglas

- **NUNCA postea** (núcleo del contrato). Devolvés el texto; César publica.
- **No leas el hilo ni el código** — `voice` es autocontenido por diseño. Si el texto depende del contexto, deriva (paso 3).
- **No dupliques criterios** — todo lo que evaluás vive en §3.5 (filtro calidad, autocontenidos) y en el contrato. Acá solo se **invoca**.
- El recordatorio de voz humana también vive en el hook `linear-write-guard.sh` (red de seguridad al publicar); `voice` es el paso **proactivo** que evita llegar ahí con un texto crudo.
