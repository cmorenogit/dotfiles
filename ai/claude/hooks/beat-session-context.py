#!/usr/bin/env python3
"""Beat session context (SessionStart).

Al abrir una sesión en un worktree de Beat cuya rama trae un ID de issue (ryr-286, pla-29…),
inyecta la FOTO de su bitácora (sección "Estado actual" + "Decisiones abiertas") como contexto.

Por qué: la regla "leé la bitácora primero" vivía solo como instrucción y en sep-2026 César tuvo
que preguntar "¿en qué estado está?" ~20 veces (RYR-286, 298, 299, 300). Inyectar es más fiable
que pedir. Presupuesto chico (la foto de la bitácora es ≤80 palabras por diseño). Fail-open: ante
cualquier error no inyecta nada.
"""
import json
import os
import re
import subprocess
import sys

VAULT_ISSUES = os.path.expanduser("~/Code/_vault/_work/apprecio/projects/rr/issues")
MAX_CHARS = 2500


def git(args, cwd):
    try:
        r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=3)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def section(text, heading_prefix):
    """Devuelve la sección cuyo H2 empieza con heading_prefix, hasta el próximo H2."""
    m = re.search(rf"^## {re.escape(heading_prefix)}.*?$(.*?)(?=^## |\Z)", text, re.S | re.M)
    return m.group(0).strip() if m else ""


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}
    cwd = payload.get("cwd") or os.getcwd()
    remote = git(["config", "--get", "remote.origin.url"], cwd)
    if not any(k in remote for k in ("apprecio-pulse", "ryr-39255", "ryr-app")):
        return
    branch = git(["branch", "--show-current"], cwd)
    m = re.search(r"(ryr|pla|app)[-_]?(\d+)", branch, re.I)
    if not m:
        return
    issue = f"{m.group(1).upper()}-{m.group(2)}"
    path = os.path.join(VAULT_ISSUES, issue, "00-bitacora.md")
    if not os.path.isfile(path):
        print(f"[beat] Rama de {issue}: no tiene bitácora en el vault ({path}). "
              f"Si el issue cruza sesiones, proponé crearla con /bitacora.")
        return
    text = open(path, encoding="utf-8").read()
    parts = [p for p in (section(text, "Estado actual"), section(text, "Decisiones abiertas")) if p]
    if not parts:
        print(f"[beat] Bitácora de {issue}: {path} (sin sección 'Estado actual'; leela antes de actuar).")
        return
    # Borradores sin publicar del issue (convención de /implementar: frontmatter status: borrador).
    pend = []
    folder = os.path.dirname(path)
    for f in sorted(os.listdir(folder)):
        if f.startswith("publicar-") and f.endswith(".md"):
            head = open(os.path.join(folder, f), encoding="utf-8").read(400)
            if re.search(r"^status:\s*borrador\s*$", head, re.M):
                pend.append(f)
    body = "\n\n".join(parts)
    if len(body) > MAX_CHARS:
        body = body[:MAX_CHARS] + "\n…(recortado; leé la bitácora completa)"
    if pend:  # después del recorte: los borradores pendientes nunca se pierden
        body += ("\n\n## Borradores SIN PUBLICAR\n" + "\n".join(f"- {folder}/{f}" for f in pend)
                 + "\n(César publica; al confirmar, marcar `status: publicado`.)")
    print(f"[beat] FOTO de la bitácora de {issue} ({path}) — punto de partida de esta sesión; "
          f"verificá contra Linear/GitHub antes de afirmar estados de otros:\n\n{body}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
