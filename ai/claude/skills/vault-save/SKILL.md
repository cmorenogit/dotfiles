---
name: vault-save
description: Hub para guardar CUALQUIER documento en el vault (~/Code/_vault), de trabajo o personal, desde cualquier proyecto. Clasifica el doc, lo rutea a la carpeta correcta según el mapa de ruteo del vault, aplica el formato estándar (frontmatter + kebab-case) y hace commit + push inmediato. Triggers: "guardá esto en el baúl/vault", "persistí este doc", "/vault-save", y SIEMPRE antes de cualquier Write de un documento persistente bajo ~/Code/_vault.
---

# vault-save — hub de guardado del vault

El objetivo: que todo lo guardado quede **ordenado y retomable** — especialmente el trabajo por issue de Linear, que César revisa por carpeta de issue.

## Flujo (orden estricto)

1. **Leer el mapa:** `~/Code/_vault/CLAUDE.md` (tabla de ruteo + formato). Es la fuente de verdad; esta skill no la duplica.
2. **Clasificar el documento:**
   - ¿Trata de un issue de Linear (análisis, propuesta, plan, review, postmortem, contexto)? → extraer `ISSUE-ID` y resolver el proyecto (RYR→rr, APP→app, Platform→fuerza/sl/engagement según módulo) → `_work/apprecio/projects/<slug>/issues/<ISSUE-ID>/`. Crear la carpeta si no existe. Issue sin proyecto claro → `_work/apprecio/_shared/issues/<ISSUE-ID>/`.
   - ¿Doc de proyecto sin issue? → `_work/apprecio/projects/<slug>/` (PRDs → `prds/`).
   - ¿Cross-proyecto? → `_work/apprecio/_shared/`. ¿Personal? → `_personal/`.
3. **Resolver nombre + frontmatter** según el formato estándar del mapa. Si la carpeta del issue usa prefijos numerados (`00-`, `01-`…), continuar la secuencia.
4. **Ambigüedad:** si el destino no matchea una regla del mapa o requiere una carpeta nueva fuera del árbol → preguntar a César (AskUserQuestion) ANTES de escribir. Si matchea exacto → escribir directo e informar el destino.
5. **Escribir** el archivo.
6. **Commit + push inmediato** — solo los archivos de este guardado:
   ```bash
   cd ~/Code/_vault && git add <archivos> && git commit -m "docs(<scope>): <qué>" && git pull --rebase && git push
   ```
   `<scope>` = team del issue (ej. `ryr`) o slug del proyecto. Si el push falla, resolver y reintentar — un guardado sin push no está terminado.
7. **Informar:** ruta final + hash del commit, en una línea.

## Reglas duras

- Nunca escribir en la raíz del vault.
- Doc de issue → carpeta del issue (`projects/<slug>/issues/<ISSUE-ID>/`), NUNCA en `projects/<slug>/` raíz.
- No commitear archivos ajenos a este guardado: el vault suele tener trabajo en curso de otros flujos.
