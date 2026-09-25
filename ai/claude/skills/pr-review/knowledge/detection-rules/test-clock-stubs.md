# Test clock stubs — el test fija un valor que el producto resuelve

Un stub de test fabrica por su cuenta un valor que el código de producto **resuelve** — el offset de una zona horaria, el huso de un país, la moneda del tenant — y después la aserción compara ese dato contra la resolución real del producto. Mientras los dos coincidan el test pasa. El día que la fuente real cambia sin que nadie toque el repositorio (un cambio de horario, una variable de entorno, una fila de configuración), el test falla **sin que haya ningún bug**.

Estos fallos no se parecen a una regresión: el diff del PR que los descubre no tiene nada que ver con el test que se cayó, y el código de producto está correcto. Por eso el tiempo de diagnóstico es alto y el daño se reparte: un stub de reloj roto en un archivo de `service` deja el job de tests en rojo para **todo** PR del repositorio, no solo para los del dominio que lo contiene.

Formulación operativa para la revisión: **si el producto tiene una función que resuelve el valor, el stub la usa; no la reimplementa ni la aproxima.**

## Trigger

Activar esta regla si el PR añade o modifica archivos bajo `__tests__/` (cualquier profundidad: `unit/`, `service/`, `integration/`, `helpers/`) **y** el contenido añadido o modificado presenta al menos una de estas tres señales.

### Señal 1 — literal con forma de offset horario

```
['"][+-][0-9]{2}:[0-9]{2}['"]
```

Un `'-04:00'`, `'+02:00'`, `'-05:00'` en un archivo de test. Es la señal más barata y la más directa: un offset escrito a mano es, por definición, la posición de un reloj respecto de otro.

### Señal 2 — variable de entorno de zona horaria, o derivación propia del huso

```
Deno\.env\.(get|set)\(['"][^'"]*(TZ|TIMEZONE|TIME_ZONE)[^'"]*['"]\)
\b[A-Z][A-Z0-9]*_(TZ|TIMEZONE)(_[A-Z0-9]+)?\b
Intl\.DateTimeFormat\([^)]*timeZone
```

El test consulta la variable de entorno que gobierna el huso, o deriva el offset por su cuenta con `Intl`. Dos precisiones que la calibración obligó a hacer:

1. **El regex debe exigir el identificador completo, nunca la subcadena `TZ` suelta.** Los JWT de prueba en base64 de esta suite contienen `TZ` por accidente (`...ODM4MTI5OTZ9`): un grep de `TZ` a secas devuelve **43 archivos** de puro ruido.
2. **Un huso IANA literal (`'America/Santiago'`) NO está en el trigger.** Medido: no aporta ningún verdadero positivo en esta suite y suma 4 archivos de ruido, todos casos donde el huso es un campo de configuración del fixture o el valor asertado de un catálogo (ver Anti-FP #4). Queda como **señal de apoyo**: si ya hay un candidato abierto por S1, S2 o S3, un IANA literal dentro del propio stub refuerza el hallazgo; por sí solo no abre nada.

### Señal 3 — desplazamiento por horas enteras sobre una fecha que se serializa

```
([1-9]|1[0-4]) *\* *3_?600_?000        # N horas, con N entre 1 y 14
```
**en conjunción con** formateo de la hora al shape del dominio en el mismo archivo:
```
getUTCHours|getUTCMinutes|\b(AM|PM)\b
```
**y excluyendo** los desplazamientos por días:
```
descartar si la línea contiene  24 *\*  |  \* *24  |  slice\(0, *10\)
```

Esta señal es la que atrapa el caso que las dos primeras dejan pasar: un `new Date(atMs - 4 * 3_600_000)` no contiene ningún literal con forma de offset ni nombra ninguna zona, pero es un reloj corrido a mano. El 4 de `4 * 3_600_000` **es** un `-04:00` escrito en otra base.

**Las tres condiciones son necesarias, y cada una fue calibrada contra un modo de falso positivo real:**

1. *El rango 1–14 horas.* Ningún offset del mundo pasa de ±14. Los desplazamientos grandes son duraciones.
2. *La conjunción con el formateo de la hora.* Sin ella, la señal es el guard ingenuo que el análisis del incidente descarta de entrada: `Date.now() ± N` aparece en **176 líneas** de esta suite y casi todas son duraciones legítimas (edad de un batch, ventana de un desafío, expiración de un token). Una duración no se desalinea con nada, porque el producto no la reinterpreta con un huso. Lo que delata al reloj es lo que viene después del desplazamiento: `getUTCHours()`, `% 12`, `AM/PM` — la fecha se está serializando al shape que el producto va a reinterpretar con **su** offset.
3. *La exclusión de días.* Los dos únicos falsos positivos que sobrevivían a la conjunción eran `24 * 60 * 60 * 1000` (mañana) y `2 * 24 * 60 * 60 * 1000` (anteayer), ambos recortados a `.slice(0, 10)` — una fecha sin hora nunca es un reloj. Excluir el factor 24 los elimina sin perder ningún verdadero positivo.

### Calibración del trigger sobre `apprecio-pulse`

Medido sobre el árbol inmediatamente anterior al fix (`50172ff3d^`), **907 archivos de test** en `supabase/functions/**/__tests__/`:

| Señal | Archivos alcanzados | Verdaderos positivos | Falsos positivos |
|-------|--------------------:|---------------------:|------------------|
| Señal 1 (`±HH:MM`) | 2 | 1 | 1 (el unit del resolvedor) |
| Señal 2 (env de tz / `Intl`) | 2 | 1 | 1 (el mismo unit) |
| Señal 3 (horas 1–14 ∧ formateo, sin días) | 2 | **2** | 0 |
| **Unión de las tres** | **4 de 907** | **3 de 3 stubs culpables** | 1 |

Variantes descartadas durante la calibración, con el costo medido de cada una:

| Variante descartada | Alcance | Verdaderos positivos que aportaba |
|---------------------|--------:|-----------------------------------|
| `Date.now() *[-+]` (el guard ingenuo) | 176 líneas | — |
| `TZ` como subcadena suelta | 43 archivos | 0 adicionales (ruido de JWT en base64) |
| `3_600_000` sin conjunción ni exclusión | 24 archivos | 0 adicionales |
| Huso IANA literal (`'America/…'`) | +4 archivos | 0 |

Dos conclusiones que conviene no perder:

1. **Las señales 1 y 2 solas habrían atrapado 1 de los 3 stubs del incidente.** Los otros dos escribían el offset como `4 * 3_600_000`, sin literal con forma de offset ni mención de ninguna zona. Por eso la señal 3 es parte del trigger y no una nota al pie.
2. **El único falso positivo que sobrevive es el test del propio resolvedor** (Anti-FP #2), que la regla cierra en un paso con la heurística de "lado asertado vs. lado de setup".

### No aplica a

1. Archivos de producto (`services/*.ts`, `routes/*.ts`, `index.ts`). Ahí el offset literal suele ser el fallback legítimo del resolvedor — es justamente el valor que el test no debe duplicar.
2. Fixtures y snapshots con fechas congeladas que **no** se comparan contra ninguna resolución del producto (un `created_at` de seed que solo se lee de vuelta).
3. Repos o módulos sin resolvedor de producto para el valor: ahí no hay nada que reusar y el hallazgo baja a WARN (ver severidades).

## Skills que la consumen

1. **`pr-review-tests`** (invocada desde `pr-review/SKILL.md` Step 3) — consumidora única. Es la skill que juzga si un test prueba lo que dice probar: su sección **C) Real Production Code Exercised?** ya clasifica tests por si invocan código de producto o reimplementan su lógica, y este patrón es exactamente esa reimplementación, en su forma más difícil de ver. El hallazgo se reporta en C) y, con el fix concreto, en **E) Prioritized Improvements**.

2. **CCC — evaluada y descartada, con razón.** `pr-review-ccc/SKILL.md:78` declara: *"Do NOT flag test files for production-level concerns unless there's a security leak in test data"*. Declarar CCC consumidora pondría la regla en conflicto con el guardrail explícito de esa skill y duplicaría el hallazgo sin añadir ningún lente nuevo. Las dos reglas hermanas sí incluyen CCC porque su patrón vive en código de producto que cruza capas (`economic-grants`: edge functions + RPC + `_shared`; `migration-timestamps`: migraciones + módulos). Este vive solo en archivos de test.

3. **Excepción acotada:** si el PR toca **en el mismo diff** el archivo de test y el resolvedor de producto que el stub debería reusar, el riesgo sí cruza capas — se puede cambiar un lado y no el otro. Solo en ese caso, inyectar la regla también en el agente CCC, con el alcance limitado a verificar que ambos lados siguen leyendo la misma fuente. Fuera de ese caso, `pr-review-tests` y nada más.

4. **G1–G5 no aplican por construcción:** `pr-review/SKILL.md` Step 0 lista `__tests__/*`, `*.spec.ts` y `*.test.ts` en sus **Skip patterns**, así que los archivos que disparan esta regla nunca llegan a esos subagentes. Es la razón por la que la regla necesita una consumidora en Step 3 y no una en Pass 1.

## Regla vigente

El eje del juicio no es *"¿el test usa el valor correcto?"* sino *"¿de dónde saca el valor?"*. Un stub puede tener el valor correcto hoy y seguir siendo un MUST FIX, porque la corrección fue una coincidencia de fecha.

### Severidades

| Patrón detectado | Severidad | Razón |
|------------------|-----------|-------|
| Stub fija un literal de offset o huso y la aserción depende de que el producto resuelva el mismo valor, existiendo un resolvedor exportado | **MUST FIX** | Es el patrón del incidente. Falla sola en el próximo cambio de la fuente real, sin bug y sin diff que la explique. |
| Stub desplaza la fecha por una constante de horas enteras (`N * 3_600_000`) y la serializa al shape del dominio, sin pasar por el resolvedor | **MUST FIX** | El mismo defecto escrito en otra base. El comentario suele confesarlo (`// aproximación -04:00`). |
| Stub **calcula** el valor por su cuenta con el huso IANA correcto, pero sin llamar al resolvedor del producto | **MUST FIX** | El matiz del override: el resolvedor admite un override por variable de entorno y lo consulta **antes** que el huso. Un stub que calcula "bien" por su cuenta se desalinea en cuanto alguien fija esa variable, y reintroduce el mismo fallo **sin la señal del cambio de horario**. La regla no es "usa el huso bien", es "usa la misma función que el producto". |
| Stub lee el override del entorno pero con fallback a un literal fijo (`Deno.env.get('DDM_REPORT_TZ_OFFSET') ?? '-04:00'`) | **MUST FIX** | Engaña al revisor: parece que respeta la configuración. En CI la variable no está puesta, así que **el fallback es la única rama que corre** y el test vuelve a fijar un reloj. |
| El producto **no** exporta resolvedor para el valor y el test lo fija a mano | **WARN / SHOULD FIX** | No hay nada que reusar todavía. Pedir que se exporte el resolvedor, o que el valor se centralice en un helper compartido de test con el comentario de por qué. No bloquea por sí solo. |
| Señal 3 presente, pero no se pudo confirmar que la aserción cruce contra una resolución del producto | **WARN** | Candidato que necesita lectura: confirmar si el valor desplazado se compara con algo que el producto resuelve, o si es una duración. Si es duración → no es hallazgo. |
| Test del resolvedor mismo, que compara la salida de la función contra valores absolutos | **NO ES HALLAZGO** | Ver Anti-FP #2. Ahí el literal es el contrato; usar el resolvedor para calcular su propia expectativa volvería el test tautológico. |

### Cómo se verifica un candidato — tres preguntas

1. **¿El valor lo resuelve el producto en runtime?** Buscar un símbolo exportado que lo devuelva (`resolve*`, `get*Offset`, `*FromCountry`, `current*`). Si no existe → WARN, no MUST FIX.
2. **¿La aserción del test depende de que el valor del stub coincida con la resolución del producto?** Si el stub produce la entrada y el producto la interpreta con su propio resolvedor para decidir si pasa o no pasa → sí, y es MUST FIX. Si el valor solo se escribe y se lee de vuelta sin que el producto lo interprete → no es hallazgo.
3. **¿La fuente del valor puede cambiar sin que nadie toque el repositorio?** Reloj, DST, variable de entorno, tabla de configuración, catálogo externo. Si sí → el test es una bomba con fecha. Si el valor es inmutable por construcción → degradar a CONSIDER.

## Regla target

La regla vigente es reactiva: detecta el stub desalineado cuando el PR lo toca. El estado deseado añade dos cosas, ninguna de ellas presente todavía:

1. **Helper compartido de test por dimensión.** En lugar de que cada archivo de `service` derive el offset del reporte, un helper único en `__tests__/helpers/` que delegue en el resolvedor de producto. Reduce la superficie de la regla de N archivos a uno, y convierte el hallazgo en "no usaste el helper", mucho más fácil de ver en un diff.
2. **Prueba de la alineación, no solo del valor.** Un test que corra el conjunto con el override forzado a dos valores distintos — el fix del incidente lo hizo a mano con `-04:00` y `-05:00`. Si el stub sigue al producto, los dos escenarios pasan; si lo aproxima, uno falla. Eso convierte la alineación en algo verificado por CI y no por criterio de revisor.

Cuando el helper exista, el primer patrón de la tabla de severidades se reformula como "no usa el helper" y esta sección se actualiza.

## Criterio de generalización — cuándo entra una dimensión nueva

El patrón no es de zonas horarias. Es *"el test fija lo que el producto resuelve"*, y aplica igual a la moneda del tenant, el locale, un feature flag o la versión de un contrato externo. El riesgo de escribirlo así de amplio es real: una regla que dice "todo literal en un test podría ser un valor que el producto resuelve" no discrimina nada y se vuelve inaplicable.

**Criterio:** una dimensión entra al Trigger con señales propias solo si cumple las **tres** condiciones:

1. **Hay resolvedor nombrable.** El producto expone una función que devuelve el valor. Sin esto no hay regla, hay una sugerencia de diseño.
2. **La fuente puede cambiar sin tocar el repositorio.** Reloj, DST, variable de entorno, tabla de configuración, catálogo de un tercero. Si el valor solo cambia cuando alguien edita código, el PR que lo cambie va a mostrar el test en el mismo diff y el revisor lo ve sin ayuda.
3. **El valor tiene forma literal greppeable.** Un `±HH:MM`, un código ISO-4217, un tag BCP-47, un nombre de flag. Sin forma literal el trigger no puede ser preciso, y un trigger impreciso en este subsistema es peor que no tener la regla: se activa en todo PR y gasta el presupuesto de tokens de los demás.

Estado hoy en `apprecio-pulse`: **solo la dimensión tiempo** (offset / huso) cumple las tres, y es la única con señales en el Trigger.

| Dimensión | ¿Resolvedor? | ¿La fuente cambia sola? | ¿Forma literal? | Estado |
|-----------|--------------|-------------------------|------------------|--------|
| Offset / huso horario | Sí (`resolveReportTzOffset`) | Sí (DST, `DDM_REPORT_TZ_OFFSET`) | Sí (`±HH:MM`) | **En el Trigger** |
| Moneda del tenant | Sí (`getCountryLocalization`) | Sí (settings del tenant) | Sí (ISO-4217) | Candidata — falta un caso real que justifique el costo del trigger |
| Locale / i18n | Sí (`getCountryLocalization`) | No (cambia por código) | Sí (BCP-47) | Fuera: falla la condición 2 |
| Feature flag | Sí | Sí (tabla de flags) | Parcial (nombre del flag) | Candidata — el trigger necesitaría el catálogo de flags para ser preciso |
| Versión de contrato externo | No uniforme | Sí (el tercero versiona) | No | Fuera: falla 1 y 3 |

Hasta que una candidata cumpla las tres **y** exista un caso real que la justifique, el revisor que vea el patrón en otra dimensión lo reporta con el **razonamiento** de esta regla (las tres preguntas de arriba) pero sin trigger automático. No añadir señales especulativas: cada señal imprecisa activa la regla en PRs donde no aplica, y el precedente medido acá es que las señales mal calibradas cuestan entre 24 y 176 falsos positivos cada una.

## Anti-FP claves

### 1. El literal que es el dato de la prueba, no una suposición sobre el mundo

Un assert que le pasa el offset **explícitamente** a la función que lo parsea, para probar el parser:

```typescript
// supabase/functions/_shared/apprecio/__tests__/service/aa-t2b-confirm-polling-flujo-proof.service.test.ts:237 — VÁLIDO
const ts = parseReportFecha('2026-06-11 6:37:03 PM', '-04:00');
```

**Por qué no se marca:** el `-04:00` es un parámetro de entrada de la unidad bajo prueba. El test afirma "dado este string y este offset, el parse devuelve este instante" — una propiedad de `parseReportFecha`, cierta en cualquier fecha del calendario. No hay ninguna resolución del producto contra la cual desalinearse. Pregunta 2 del chequeo: la aserción **no** depende de que el producto resuelva el mismo valor.

Nótese que este assert convive, en el mismo archivo, con el stub que sí era MUST FIX. El hallazgo se decide por línea y por rol del literal, no por archivo.

### 2. El test del resolvedor, que compara contra valores absolutos

```typescript
// supabase/functions/economic-points-api/__tests__/unit/aa-holdautorelease-status-tz.test.ts:28-34 — VÁLIDO
Deno.test('HA-U2: resolveReportTzOffset — DST chileno (-03 verano / -04 invierno)', () => {
  if (Deno.env.get('DDM_REPORT_TZ_OFFSET')) return; // override explícito: el env manda
  const enero = Date.parse('2026-01-15T12:00:00Z'); // verano CL → -03:00
  const junio = Date.parse('2026-06-15T12:00:00Z'); // invierno CL → -04:00
  assertEquals(resolveReportTzOffset('CL', enero), '-03:00');
  assertEquals(resolveReportTzOffset('CL', junio), '-04:00');
  assertEquals(resolveReportTzOffset('CO', enero), '-05:00'); // Colombia sin DST
  assertEquals(resolveReportTzOffset('XX', enero), '-04:00'); // país sin mapa → fallback
});
```

**Por qué no se marca — y por qué acá la regla se invierte:** este test *es* el contrato del resolvedor. Si usara `resolveReportTzOffset` para calcular su propia expectativa sería tautológico (`assertEquals(f(x), f(x))`) y no probaría nada. Aquí el literal absoluto es **obligatorio**: fechas fijas y offsets fijos, a propósito, porque son el enunciado de la regla DST que se quiere garantizar.

La línea 28 merece atención aparte: el test cede explícitamente ante el override del entorno. Eso es correcto en el test del resolvedor — y es lo contrario de lo que debe hacer un stub, que necesita el valor que el producto va a usar, no saltarse el caso.

**Heurística de un paso.** ¿El símbolo que produce el valor está en el lado *asertado* o en el lado del *setup*?

| Forma | Rol del literal | Veredicto |
|-------|-----------------|-----------|
| `assertEquals(resolver(x), '-04:00')` | expectativa: es el contrato | Válido |
| `productFn(dato, '-04:00')` en un assert del parser | parámetro de entrada de la unidad bajo prueba | Válido |
| el stub fabrica el dato con `'-04:00'` y el producto lo interpreta con su resolvedor | suposición sobre el mundo | **MUST FIX** |

### 3. `Date.now() ± N` como duración

176 líneas de esta suite. Edad de un batch, ventana de un desafío, expiración de un token, antigüedad para un sweep. No tocan ningún reloj: el valor es un *intervalo*, y un intervalo no se desalinea con nada porque el producto no lo reinterpreta con un huso.

Dos variantes que la calibración obligó a excluir explícitamente, porque sobrevivían a la conjunción de formateo:

```typescript
// supabase/functions/api-surveys/__tests__/service/distribute.service.test.ts:107 — VÁLIDO
const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(); // Tomorrow

// supabase/functions/ecards-api/__tests__/unit/services/cron-expire.service.test.ts:51 — VÁLIDO
const yesterday = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
```

**Por qué no se marcan:** el desplazamiento es de días, no de horas, y el resultado se recorta a fecha sin hora. Una fecha sin hora no tiene offset que desalinear. De ahí las dos exclusiones de la señal 3 (factor 24, `.slice(0, 10)`).

### 4. El huso IANA como dato de configuración o como valor asertado de un catálogo

```typescript
// supabase/functions/apprecio-api/__tests__/unit/ddm-tenant-localization.test.ts:15 — VÁLIDO
assertEquals(getCountryLocalization('cl'), { currency: 'CLP', timezone: 'America/Santiago', locale: 'es-CL', ... });

// supabase/functions/awards-api/__tests__/service/awards.service.test.ts:62 — VÁLIDO
timezone: 'America/New_York',   // campo de settings del tenant de prueba
```

**Por qué no se marcan, y por qué el IANA literal quedó fuera del trigger:** en el primero el huso es el valor **asertado** del catálogo de localización — mismo caso que Anti-FP #2, extendido a moneda y locale. En el segundo es un campo de configuración que el fixture escribe: el producto lo lee como dato, no lo resuelve para compararlo contra otra cosa. Lo mismo aplica a un huso viajando como payload de un audit log (`tenant-api/__tests__/service/audit-log.service.test.ts:157`). Los cuatro archivos de este tipo en la suite son válidos, y ninguno de los tres stubs del incidente contenía un IANA literal — por eso la señal aporta solo ruido y quedó como apoyo.

### 5. Fixtures con fecha congelada que nadie reinterpreta

Un `created_at: '2026-01-01T00:00:00Z'` en un seed, que se escribe y se lee de vuelta sin que ninguna función de producto lo interprete con un offset. No es hallazgo: no hay dos relojes, hay uno.

## Ejemplos verificables

Los tres provienen de `ivaldovinos-app/apprecio-pulse`, commit del fix `50172ff3d` (rama `fix/service-tests-dst-offset`). El código "incorrecto" es el estado en `50172ff3d^`; el "correcto" es el del commit.

### MUST FIX — el desplazamiento de horas enteras

```typescript
// supabase/functions/economic-points-api/__tests__/service/aa-holdautorelease-cases.service.test.ts:90 — INCORRECTO
function reportStub(cargaId: number, status: string, monto: number, contador: number, atMs: number) {
  // fecha del reporte en el reloj del partner (CL); formato "YYYY-MM-DD h:mm:ss AM/PM".
  const d = new Date(atMs - 4 * 3_600_000); // aproximación -04:00 (el offset real lo resuelve el matcher)
  const hh24 = d.getUTCHours();
  // ...
```

**Por qué falla:** el comentario confiesa el patrón — *"aproximación"*, y *"el offset real lo resuelve el matcher"*. El matcher llama `resolveReportTzOffset(country, createdMs)`, que es DST-aware. Mientras Santiago estuvo en `-04:00` los dos coincidieron. El 2026-09-06 Chile pasó a `-03:00` y la hora de diferencia dejó la carga en `created − 1h`, 45 minutos por debajo del piso de la ventana de match (`POLL_FECHA_TOLERANCE_MS` = 15 min, `POLL_MATCH_WINDOW_MS` = 1 h).

**Fix aplicado:**
```typescript
/** Offset del reloj del partner (±HH:MM del país del tenant) en milisegundos. */
function reportOffsetMs(atMs: number): number {
  const tz = resolveReportTzOffset(COUNTRY, atMs);
  const [h, m] = tz.slice(1).split(':').map(Number);
  return (tz.startsWith('-') ? -1 : 1) * (h * 60 + m) * 60_000;
}

function reportStub(cargaId: number, status: string, monto: number, contador: number, atMs: number) {
  // El offset sale del MISMO resolvedor que usa el matcher (DST-aware, respeta el override
  // DDM_REPORT_TZ_OFFSET): un valor fijo se desalinea en cada cambio de horario.
  const d = new Date(atMs + reportOffsetMs(atMs));
```

El país sale de una constante (`const COUNTRY = 'CL'`) que alimenta también el `settings.country` del tenant de prueba — una sola fuente para el dato del tenant y para el reloj derivado de él. Que el fix elimine el literal es lo que hace que la señal 3 sea verificable en el diff: la línea marcada desaparece.

### MUST FIX — el override con fallback fijo

```typescript
// supabase/functions/_shared/apprecio/__tests__/service/aa-t2b-confirm-polling-flujo-proof.service.test.ts:102 — INCORRECTO
function fechaFor(date: Date): string {
  // Shape real del reporte: "2026-06-11 6:37:03 PM" en el reloj del partner.
  const tz = Deno.env.get('DDM_REPORT_TZ_OFFSET') ?? '-04:00';
```

**Por qué falla, y por qué es el más engañoso de los tres:** lee la misma variable de entorno que el resolvedor, así que a primera vista respeta la configuración. Pero el `??` deja un literal fijo como única rama que corre cuando la variable no está puesta — que es exactamente el caso de CI. El test fijaba un reloj con la apariencia de estar leyéndolo.

**Fix aplicado:**
```typescript
const tz = resolveReportTzOffset(COUNTRY, date.getTime());
```

Una línea. El override se sigue respetando, porque `resolveReportTzOffset` lo consulta primero, y cuando no está puesto deriva el offset del huso IANA del país a la fecha de la carga en vez de adivinarlo.

### MUST FIX — la variante con `Date.now()`

```typescript
// supabase/functions/economic-points-api/__tests__/service/aa-holdautorelease-flujo-proof.service.test.ts:47 — INCORRECTO
function stubReport(cargaId: number, status: string, monto: number) {
  const d = new Date(Date.now() - 4 * 3_600_000);
```

**Por qué falla:** idéntico al primero, sin el comentario que lo confesaba. Este es el caso que obliga a la conjunción de la señal 3: aislada, la línea es indistinguible de las 176 duraciones legítimas de la suite. Lo que la delata es el formateo que viene después — `getUTCHours()`, `% 12`, `AM/PM`.

**Fix aplicado:** el mismo helper `reportOffsetMs` basado en `resolveReportTzOffset`, con `atMs = Date.now()` calculado **una vez** y usado tanto para el offset como para la fecha. Calcularlo dos veces reintroduce una ventana de carrera propia.

### Referencia — el resolvedor de producto que el stub debe reusar

```typescript
// supabase/functions/economic-points-api/services/apprecio-send.service.ts:110 — no es hallazgo
/** Offset (±HH:MM) del país del tenant a la fecha dada, DST-aware. */
export function resolveReportTzOffset(country: string, atMs: number): string {
  if (DDM_REPORT_TZ_OFFSET) return DDM_REPORT_TZ_OFFSET; // override explícito
  const zone = REPORT_TZ_BY_COUNTRY[String(country ?? '').toUpperCase()];
  // ... Intl.DateTimeFormat con timeZoneName: 'longOffset'
  return '-04:00';
}
```

Está exportada, toma la fecha como parámetro (por eso es DST-aware) y consulta el override antes que nada: los tres elementos que hacen que un stub que la llame no pueda desalinearse. El literal `'-04:00'` del final es el fallback del producto para un país sin mapa — legítimo acá, y precisamente el valor que el test no debe duplicar por su cuenta.

## Verificación rápida en code review

```bash
# Archivos de test tocados por el PR
TEST_FILES=$(gh pr view {prNumber} -R {repo} --json files --jq '.files[].path' \
  | grep -E '__tests__/.*\.(test|spec)\.ts$')

# Señal 1 — literal con forma de offset, solo en líneas añadidas
gh pr diff {prNumber} -R {repo} | grep -nE "^\+.*['\"][+-][0-9]{2}:[0-9]{2}['\"]"

# Señal 2 — env de tz o derivación propia del huso.
# El identificador va completo: un grep de 'TZ' suelto matchea los JWT en base64 (43 archivos de ruido).
gh pr diff {prNumber} -R {repo} | grep -nE "^\+.*(Deno\.env\.(get|set)\(['\"][^'\"]*(TZ|TIMEZONE|TIME_ZONE)[^'\"]*['\"]|[A-Z][A-Z0-9]*_(TZ|TIMEZONE)\b|Intl\.DateTimeFormat\([^)]*timeZone)"

# Señal 3 — desplazamiento de 1..14 horas, en archivos que formatean la hora, excluyendo días
for f in $TEST_FILES; do
  grep -qE "getUTCHours|getUTCMinutes|\b(AM|PM)\b" "$f" || continue
  hits=$(grep -nE "([1-9]|1[0-4]) *\* *3_?600_?000" "$f" | grep -vE "24 *\*|\* *24|slice\(0, *10\)")
  [ -n "$hits" ] && { echo "CANDIDATO: $f"; echo "$hits"; }
done
```

Para cada match, correr las tres preguntas de "Cómo se verifica un candidato" y clasificar según la tabla de severidades. Si el match es un assert que **recibe** el valor como parámetro, o el test del propio resolvedor, cerrarlo como Anti-FP #1 o #2 sin reportarlo.

### Fix sugerido para el report

Cuando la regla dispare con MUST FIX, el report debe nombrar el símbolo concreto a reusar — sin eso el hallazgo es una queja, no un Quick Win:

```markdown
**Fix sugerido:** el stub deriva el valor con la misma función que usa el producto:
\`\`\`typescript
import { resolveReportTzOffset } from '../../services/apprecio-send.service.ts';
const tz = resolveReportTzOffset(COUNTRY, atMs);
\`\`\`
No basta con corregir el literal al valor de hoy: el override por entorno y el próximo
cambio de horario vuelven a desalinearlo.
```

## Historia / contexto

1. **Incidente del 2026-09-07 (`apprecio-pulse`, equipo Beat, RYR-179).** Chile adelantó los relojes el 2026-09-06 y Santiago pasó a `-03:00`. Los tres stubs de arriba escribían la fecha del reporte del partner restando 4 horas fijas; el matcher la interpreta con `resolveReportTzOffset(country, atMs)`. La hora de diferencia dejó la carga fuera de la ventana de match de una hora y **los 7 casos que emparejan por fecha cayeron en bloque**: `aa-holdautorelease-cases` HA-1, `aa-holdautorelease-flujo-proof` HA-P1, y `aa-t2b-confirm-polling-flujo-proof` T2b A/B/F/H/I.

2. **El daño no fue proporcional al defecto.** `backend-tests` quedó en rojo para **todo** PR del repositorio, no solo para los del dominio económico — visto en los PRs #938 y #985. El código de producto siempre estuvo correcto; el defecto vivía únicamente en los stubs. Sin intervención se habría curado solo el 2027-04-03, cuando Chile volviera a `-04:00`.

3. **Por qué existe esta regla.** Pedido explícito de @ivaldovinos en RYR-179 (2026-09-08): *"Recuerda actualizar también donde corresponda el pr-review para que atrape este error en el futuro."* El fix de los tests es `50172ff3d`, con spec `docs/specs/2026-09-08-service-tests-dst-offset.md` en `apprecio-pulse`.

4. **Por qué ningún control previo lo atrapó.** El gate de ADLC valida que exista evidencia runtime, no que el stub lea la misma fuente que el producto. Pass 1+2 de `/pr-review` no mira archivos de test (están en los Skip patterns del Step 0). `pr-review-tests` sí los mira, pero su matriz de cumplimiento pregunta por convenciones y por *"test behavior not implementation"* — ninguna de las dos nombra este patrón. Y el unit que cubre el resolvedor (`aa-holdautorelease-status-tz.test.ts`, HA-U1/U2/U3) estuvo en verde todo el tiempo: prueba la función, no la alineación de los stubs con ella. **Un resolvedor con test propio no protege a los stubs que lo ignoran** — esa es la lección que la regla codifica.

5. **La verificación que cierra el patrón.** El fix se validó corriendo los tres archivos en tres escenarios de offset: derivado del día (verano CL, `-03:00`), override forzado a `-04:00` (invierno CL) y a `-05:00` (reloj peruano). 17 passed / 0 failed en los tres, contra una línea base de 10 passed / 7 failed. Un stub alineado pasa en los tres; uno que aproxima falla en al menos uno — ese es el criterio de aceptación que la Regla target propone automatizar.
