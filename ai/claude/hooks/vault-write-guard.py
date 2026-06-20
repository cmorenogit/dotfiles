#!/usr/bin/env python3
"""Vault write guard (PreToolUse/Write).

Aplica el mapa de ruteo del vault (~/Code/_vault/CLAUDE.md):
 1. Nada se escribe en la raiz del vault.
 2. Un doc que declara `issue:` en su frontmatter vive en una carpeta de issue:
    _work/apprecio/projects/<slug>/issues/<ISSUE-ID>/ o _work/apprecio/_shared/issues/<ISSUE-ID>/
    (exentos: linear/ y weekly/, gestionados por las skills linear-*).
 3. Rutas RETIRADAS (reestructuracion 2026-06-12): reviews/ raiz, _work/apprecio/triage/,
    _archive/ (solo lectura) y archivos sueltos directos en _work/apprecio/.

Disciplina anti-fragmentacion (skill /vault, 2026-06-20). SOLO en archivos NUEVOS bajo
projects/ (grandfathering: los existentes no se tocan, se normalizan al triar):
 A. `type` debe estar en el enum CERRADO (no inventar types).
 B. No un 2do doc del mismo `type` en una carpeta-tema (consolidar). Escape: `split:` en frontmatter.
 C. Sin sufijos de version en el nombre (-v2/-final/CONSOLIDADO/-fase1). git versiona.
    Excepcion: snapshot con proposito = nombre-YYYY-MM-DD-razon.
 Reglas A/B no aplican a COLECCIONES (reviews/, prds/) donde un-archivo-por-entidad es correcto.
"""
import json
import os
import re
import sys

VAULT_MARKER = "/Code/_vault/"
ROOT_ALLOWED = {"CLAUDE.md", "README.md", ".gitignore", "MEMORY.md"}
ISSUES_DIR_RE = re.compile(r"^_work/apprecio/(projects/[^/]+|_shared)/issues/")
ISSUE_EXEMPT_PREFIXES = ("_work/apprecio/linear/", "_work/apprecio/weekly/")
RETIRED = (
    ("reviews/",
     "ruta retirada: los reports van a _work/apprecio/projects/<slug>/issues/<ID>/ "
     "(si hay issue) o projects/<slug>/reviews/<repo>/"),
    ("_work/apprecio/triage/",
     "ruta retirada: cards por issue -> projects/rr/issues/<ID>/triage.md; "
     "cola diaria -> _work/apprecio/linear/today/"),
    ("_work/apprecio/_archive/",
     "_archive es solo lectura — no se crea contenido nuevo ahi"),
)

# --- disciplina anti-fragmentacion (skill /vault) ---
TYPE_ENUM = {
    "analisis", "propuesta", "plan", "review", "investigacion", "postmortem",
    "nota", "referencia", "triage", "handoff", "borrador", "prd",
}
PROJECTS_RE = re.compile(r"^_work/apprecio/projects/[^/]+/")
# colecciones bajo projects/: un archivo por entidad, no se consolida
COLLECTION_RE = re.compile(r"^_work/apprecio/projects/[^/]+/(reviews|prds)/")
VERSION_SUFFIX_RE = re.compile(r"(-v\d+|-final|-fase\d+|consolidado)", re.I)
DATE_SNAPSHOT_RE = re.compile(r"-\d{4}-\d{2}-\d{2}")


def deny(msg: str) -> None:
    print(f"Vault guard: {msg} (ver ~/Code/_vault/CLAUDE.md)", file=sys.stderr)
    sys.exit(2)


def fm_value(content: str, key: str):
    """Valor de `key` en el frontmatter real (bloque --- al inicio)."""
    if not content.startswith("---"):
        return None
    end = content.find("\n---", 3)
    fm = content[:end] if end != -1 else content
    m = re.search(rf"^{key}:\s*\[?\"?([^\"\n\]]+)", fm, re.M)
    return m.group(1).strip() if m else None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path") or ""
    if VAULT_MARKER not in path:
        sys.exit(0)

    rel = path.split(VAULT_MARKER, 1)[1]
    basename = rel.rsplit("/", 1)[-1]
    content = tool_input.get("content") or ""

    # Regla 1: raiz del vault
    if "/" not in rel and rel not in ROOT_ALLOWED:
        deny(f"'{rel}' caeria en la RAIZ del vault. Nada se guarda en la raiz — "
             "rutealo segun el mapa o usa /vault")

    # Regla 3a: rutas retiradas
    for prefix, msg in RETIRED:
        if rel.startswith(prefix):
            deny(f"'{rel}' — {msg}")

    # Regla 3b: archivos sueltos directos en _work/apprecio/ (dotfiles de flujos exentos)
    inner = rel[len("_work/apprecio/"):] if rel.startswith("_work/apprecio/") else None
    if inner is not None and inner and "/" not in inner and not inner.startswith("."):
        deny(f"'{rel}' quedaria suelto en _work/apprecio/ — todo documento vive "
             "dentro de una seccion (linear/, projects/, _shared/, weekly/, ...)")

    if not rel.endswith(".md"):
        sys.exit(0)

    # Regla 2: doc de issue fuera de una carpeta de issue.
    if not ISSUES_DIR_RE.match(rel) and not rel.startswith(ISSUE_EXEMPT_PREFIXES):
        issue = fm_value(content, "issue")
        if issue and re.match(r"^[A-Z]+-\d+$", issue):
            deny(f"el doc declara issue {issue} pero el destino '{rel}' no esta en una "
                 f"carpeta de issue. Guardalo en _work/apprecio/projects/<slug>/issues/{issue}/")

    # --- disciplina anti-fragmentacion: SOLO archivos NUEVOS bajo projects/ (grandfathering) ---
    if not PROJECTS_RE.match(rel) or os.path.exists(path):
        sys.exit(0)

    stem = basename[:-3]

    # Regla C: sufijos de version en el nombre (toda carpeta de projects/, salvo snapshot fechado)
    if VERSION_SUFFIX_RE.search(stem) and not DATE_SNAPSHOT_RE.search(stem):
        deny(f"'{basename}' usa un sufijo de version (-v2/-final/CONSOLIDADO/-fase1). "
             "git versiona, no los nombres — consolida en el doc vivo. Si es un snapshot "
             "con proposito, usa nombre-YYYY-MM-DD-razon.")

    # Reglas A/B: solo carpetas-tema (no colecciones reviews/, prds/)
    if COLLECTION_RE.match(rel):
        sys.exit(0)

    new_type = fm_value(content, "type")

    # Regla A: type fuera del enum cerrado
    if new_type and new_type not in TYPE_ENUM:
        deny(f"type '{new_type}' no esta en el enum cerrado "
             f"({', '.join(sorted(TYPE_ENUM))}). Inventar types es la causa raiz de la "
             "fragmentacion — usa uno del enum (o 'nota' si ninguno encaja).")

    # Regla B: 2do doc del mismo type en la carpeta-tema (default consolidar; escape split:)
    if new_type and not fm_value(content, "split"):
        folder = os.path.dirname(path)
        try:
            siblings = [f for f in os.listdir(folder)
                        if f.endswith(".md") and f != basename and not f.startswith("00-")]
        except OSError:
            siblings = []
        for sib in siblings:
            try:
                with open(os.path.join(folder, sib), encoding="utf-8") as fh:
                    head = fh.read(2000)
            except OSError:
                continue
            if fm_value(head, "type") == new_type:
                deny(f"ya existe '{sib}' con type:{new_type} en esta carpeta. Consolida ahi "
                     f"(default). Si es contenido genuinamente distinto, agrega "
                     "'split: <razon>' al frontmatter del nuevo doc.")

    sys.exit(0)


if __name__ == "__main__":
    main()
