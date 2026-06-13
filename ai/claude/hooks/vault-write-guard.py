#!/usr/bin/env python3
"""Vault write guard (PreToolUse/Write).

Aplica el mapa de ruteo del vault (~/Code/_vault/CLAUDE.md):
 1. Nada se escribe en la raiz del vault.
 2. Un doc que declara `issue:` en su frontmatter vive en una carpeta de issue:
    _work/apprecio/projects/<slug>/issues/<ISSUE-ID>/ o _work/apprecio/_shared/issues/<ISSUE-ID>/
    (exentos: linear/ y weekly/, gestionados por las skills linear-*).
 3. Rutas RETIRADAS (reestructuracion 2026-06-12): reviews/ raiz, _work/apprecio/triage/,
    _archive/ (solo lectura) y archivos sueltos directos en _work/apprecio/.
"""
import json
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


def deny(msg: str) -> None:
    print(f"Vault guard: {msg} (ver ~/Code/_vault/CLAUDE.md)", file=sys.stderr)
    sys.exit(2)


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

    # Regla 1: raiz del vault
    if "/" not in rel and rel not in ROOT_ALLOWED:
        deny(f"'{rel}' caeria en la RAIZ del vault. Nada se guarda en la raiz — "
             "rutealo segun el mapa o usa /vault-save")

    # Regla 3a: rutas retiradas
    for prefix, msg in RETIRED:
        if rel.startswith(prefix):
            deny(f"'{rel}' — {msg}")

    # Regla 3b: archivos sueltos directos en _work/apprecio/ (dotfiles de flujos exentos)
    inner = rel[len("_work/apprecio/"):] if rel.startswith("_work/apprecio/") else None
    if inner is not None and inner and "/" not in inner and not inner.startswith("."):
        deny(f"'{rel}' quedaria suelto en _work/apprecio/ — todo documento vive "
             "dentro de una seccion (linear/, projects/, _shared/, weekly/, ...)")

    # Regla 2: doc de issue fuera de una carpeta de issue.
    # Solo cuenta el frontmatter real (bloque --- al inicio del archivo).
    content = tool_input.get("content") or ""
    if rel.endswith(".md") and not ISSUES_DIR_RE.match(rel) and not rel.startswith(ISSUE_EXEMPT_PREFIXES):
        fm = ""
        if content.startswith("---"):
            end = content.find("\n---", 3)
            fm = content[:end] if end != -1 else ""
        match = re.search(r"^issue:\s*\[?\"?([A-Z]+-\d+)", fm, re.M)
        if match:
            issue = match.group(1)
            deny(f"el doc declara issue {issue} pero el destino '{rel}' no esta en una "
                 f"carpeta de issue. Guardalo en _work/apprecio/projects/<slug>/issues/{issue}/")

    sys.exit(0)


if __name__ == "__main__":
    main()
