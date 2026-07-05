---
name: bitacora
description: >
  bitácora — fuente de verdad viva de UN issue: un índice de 3 niveles (Producto · Seguimiento ·
  Decisiones con pivoteo) en el vault, para que ninguna compactación ni cambio de sesión pierda el
  contexto. Un solo verbo, dos direcciones — REGISTRAR/actualizar lo trabajado, o CONSULTARLA como
  memoria (validar si lo que se hace sigue alineado con lo decidido); el agente infiere cuál de cómo
  se la menciona. Úsala al arrancar/retomar un issue, al cerrar decisiones, o cuando algo deba
  alinearse con lo ya decidido. Triggers: "/bitacora", "guardá el avance en bitácora",
  "¿esto está alineado con bitácora?", "considerá la bitácora", "comienza una nueva sesión".
---

# bitacora — memoria viva por issue

Un issue = una **bitácora** (`00-bitacora.md`): el **índice** que se lee primero al retomar y se
anexa mientras se trabaja. Es el **ancla** de producto que `/compact` no puede borrar — justo donde
se pierde el "por qué" y el agente empieza a asumir.

**Tres niveles + el corazón:**
- **Producto** — qué/por qué de negocio: tus **decisiones ya condensadas** (de Linear,
  transcripciones, Drive, lo que sea). La bitácora registra la decisión, **no re-filtra las fuentes**.
- **Seguimiento** — lo técnico + lo implementado: cómo va.
- **Decisiones con pivoteo** — el registro de *se decidió X → cambió a Y → por qué*. Es lo que te
  salva cuando vos o el agente lo olvidan. **Nunca se pisa lo viejo.**

## Un verbo, dos direcciones

Decís "bitácora" (o la mencionás) y el agente infiere la **intención** de cómo lo decís:

| Dirección | Señales | Qué hace |
|---|---|---|
| **Registrar / actualizar** (escribir) | "guardá el avance", "registrá esto", o "bitácora" tras decidir cosas | **Cosecha** lo trabajado → **propone** qué anexar → confirmás → escribe |
| **Memoria / validar** (leer) | "¿alineado con bitácora?", "considerá lo decidido", "retomemos", "comienza nueva sesión" | **Lee** y, si aplica, **compara** el trabajo vs lo decidido → avisa del **drift** |

**Regla de oro** (lo que hace seguro tener un verbo ambiguo): leer/validar es libre y no toca nada;
**escribir siempre propone y confirma**. Ante la duda → leé, nunca escribas a ciegas.

## La guarda (antes de cualquier cosa)

1. ¿El trabajo está atado a **un issue**? (rama git `feature/ryr-…`, un ID mencionado, o contexto explícito.)
2. ¿Ese issue tiene `00-bitacora.md`?

Si falta (1) → trabajo global, **no aplica** bitácora. Si falta (2) → no hay contra qué validar:
**no la inventes ni la impongas** (a lo sumo sugerí crearla si el issue cruza sesiones). Ante la duda,
no asumas bitácora. Esto vale sobre todo para la validación ambiental: sin issue + bitácora, callate.

## Branches (inferidos del estado, no se tipean)

| Estado | Branch |
|---|---|
| no existe + arrancás | **crear** |
| carpeta con docs, sin bitácora | **adoptar** |
| existe + llegás fresco | **leer** |
| existe + hubo trabajo | **cosechar** |
| existe + vas a planear/decidir | **validar** |

### crear
Llená **Producto** con tus **decisiones condensadas** — vos traés la síntesis de las fuentes
(Linear / transcript / Drive); Linear es insumo opcional, **no** la única verdad ni un filtro a
re-correr. Seguimiento/Decisiones: esqueleto. Escribí desde [`TEMPLATE.md`](TEMPLATE.md). Lo que no
sepas → `<pendiente>`. _Hecho cuando:_ existe el doc, Producto tiene tus decisiones reales, pusheado.

### adoptar (issue ya avanzado, con docs)
No arranques de cero ni dupliques. **Leé** los docs (`analisis*`, `seguimiento*`, `triage*`),
**destilá** los 3 niveles al índice y **enlazá** los originales como *Docs profundos* (`[[wikilink]]`)
— quedan intactos. El índice lleva **titular + link**, no copia el detalle (single source of truth).
**Curá staleness:** si un doc tiene una decisión superada, registrala como **pivote**, no como viva.
**Proponé el mapeo** ("esto salió de dónde") antes de escribir.
_Hecho cuando:_ índice creado, docs enlazados, pivotes detectados, mapeo confirmado, pusheado.

### leer (retomar)
Foto compacta: **próximo paso** primero · 1 línea por nivel · últimas decisiones/pivotes · lo
`<pendiente>`. No escribe.

### cosechar (el corazón de la escritura)
Aunque te hayas olvidado de invocarla, **barré toda la sesión** desde la última actualización (o
desde el inicio): qué se decidió, qué está, qué falta. Clasificá en su nivel + **proponé** las
entradas (decisión / pivote / pendiente, con **razón + fuente**). Un solo commit. **Nunca pises el
pivoteo viejo.** _Hecho cuando:_ lo nuevo de la sesión está propuesto y confirmado en su nivel +
decision-log, pusheado.

### validar (drift-check · ambiental)
Solo si pasa **la guarda**. Leé las decisiones y compará contra lo que se está por hacer / se hizo.
Si se desvió de algo decidido → **avisá** ("ojo: X contradice la decisión de [fuente · fecha]"), no
lo corrijas en silencio. Dispará en **momentos clave** (retomar / decidir / planear), **no** en cada
mensaje — un aviso constante es ruido y lo dejás de leer.

## Pivoteo
Cuando una decisión cambia: registrá `[pivote] de X → a Y — porque <razón> — fuente: <…>` y **dejá la
entrada vieja**. El valor está en la historia, no solo en el estado actual.

## Ruteo + cierre
Ruta: `~/Code/_vault/_work/apprecio/projects/<slug>/issues/<ID>/00-bitacora.md` (slug por prefijo:
`RYR→rr` · `APP→app` · Platform→`fuerza`/`sl`/`engagement`). Siempre al vault, aun desde el repo de
código. Commit + push **solo ese archivo**:
```bash
cd ~/Code/_vault && git add _work/apprecio/projects/<slug>/issues/<ID>/00-bitacora.md \
  && git commit -m "docs(<scope>): bitácora <ID> — <qué>" && git pull --rebase && git push
```
Un guardado sin push no está terminado.

## Reglas duras
- **Una bitácora por issue**, y es el **índice**: enlaza a los docs profundos, no los absorbe.
- `type: nota`. **Append no-destructivo**; el pivoteo viejo jamás se pisa. git versiona, no los nombres.
- **Producto = tus decisiones condensadas**, no Linear crudo.
- Leer es libre; **escribir propone y confirma**.
- No inventar decisiones ni fuentes → `<pendiente>`.
