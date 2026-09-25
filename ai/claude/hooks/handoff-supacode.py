#!/usr/bin/env python3
"""Handoff → Supacode (PostToolUse/Write).

Cuando una sesión escribe `/tmp/handoff-*.md` (skill /handoff, que queda agnóstico):
  1. copia el documento a ~/.cache/handoffs/ (/tmp se borra al reiniciar; en sep-2026 se
     perdieron handoffs entre sesiones);
  2. si la sesión corre dentro de Supacode, abre EN SEGUNDO PLANO una pestaña "relevo" en el
     mismo worktree que, al presionar Enter, lanza `claude` leyendo el handoff. No arranca sola:
     no consume tokens hasta que César entra a la pestaña y confirma.
Fuera de Supacode solo copia. Fail-open.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import urllib.parse


def main():
    d = json.load(sys.stdin)
    path = (d.get("tool_input") or {}).get("file_path") or ""
    if not re.match(r"^(/private)?/tmp/handoff-[^/]+\.md$", path) or not os.path.isfile(path):
        return
    cache = os.path.expanduser("~/.cache/handoffs")
    os.makedirs(cache, exist_ok=True)
    kept = os.path.join(cache, os.path.basename(path))
    shutil.copy2(path, kept)
    if not os.environ.get("SUPACODE_SOCKET_PATH") or not shutil.which("supacode"):
        print(f"[handoff] copia persistente: {kept}")
        return
    cwd = d.get("cwd") or os.getcwd()
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=cwd,
                         capture_output=True, text=True, timeout=3).stdout.strip() or cwd
    wid = urllib.parse.quote(top.rstrip("/") + "/", safe="")
    prompt = f"Leé {kept} y continuá con lo que indica (es un handoff de otra sesión)."
    inner = (f"printf '\\n  Relevo listo: {os.path.basename(path)}\\n  Enter para abrir Claude y continuar (Ctrl+C para descartar)\\n'; "
             f"read -r _ && claude {shlex.quote(prompt)}")
    r = subprocess.run(["supacode", "tab", "new", "-w", wid, "--background", "--title", "relevo", "-i", inner],
                       capture_output=True, text=True, timeout=8)
    if r.returncode == 0:
        print(f"[handoff] copia en {kept} · pestaña 'relevo' abierta en segundo plano en Supacode "
              f"({top}); al entrar, Enter lanza la sesión nueva.")
    else:
        print(f"[handoff] copia en {kept} · no pude abrir la pestaña en Supacode: {r.stderr.strip()[:200]}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
