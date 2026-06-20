---
name: resolving-merge-conflicts
description: Resolvé un conflicto de merge/rebase en curso preservando el intent de cada lado. Úsalo cuando hay un merge/rebase trabado con conflictos, o el usuario menciona "conflicto de merge", "rebase trabado", "resolver conflictos".
---

# resolving-merge-conflicts

1. **Ver el estado** del merge/rebase: historial git y los archivos en conflicto.

2. **Encontrá la fuente primaria de cada conflicto.** Entendé a fondo por qué se hizo cada cambio y cuál era el **intent** original — leé los commit messages, el PR, el issue/ticket. (Beat → Linear `RYR-*`; el resto de Apprecio → su issue de Linear.)

3. **Resolvé cada hunk.** Preservá ambos intents donde se pueda. Donde son incompatibles, elegí el que matchea el objetivo declarado del merge y anotá el trade-off. **NO inventes comportamiento nuevo.** Siempre resolvé; **nunca `--abort`**.

4. **Quality gates del proyecto** — descubrílos y corrélos (típicamente typecheck → tests → format). Arreglá lo que el merge haya roto.
   - ⚠️ **Wrappers multi-repo** (`fuerza`/`sl`/`engagement`): cada subdirectorio es un repo git independiente — `cd` al subdirectorio del repo ANTES de cualquier comando git o de build. Nunca operar desde el wrapper.

5. **Terminá el merge/rebase.** Stage todo y commiteá (Conventional Commits en inglés). Si es rebase, continuá hasta rebasar todos los commits.
