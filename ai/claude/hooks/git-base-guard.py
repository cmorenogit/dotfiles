#!/usr/bin/env python3
"""Git base guard (PreToolUse/Bash).

Evita que una sesión escriba el árbol de trabajo de una carpeta BASE usando git para "leer"
otra rama. Incidente 15/16-sep-2026: dos sesiones con cwd en el vault corrieron
`cd back-pulse-cesar && git checkout -q <ref> -- .` y dejaron 746 archivos del padre staged
sobre `main` (HEAD no se movió, así que el reflog no lo mostró).

BASE = worktree principal de un repo (git-dir == git-common-dir) que tiene >=1 worktree
vinculado. Genérico: cubre Beat y cualquier repo futuro sin listas.

Política:
  | operación                                   | en BASE | en worktree            |
  |---------------------------------------------|---------|------------------------|
  | checkout -- <paths> / restore / read-tree   | deny    | allow (archivo puntual) |
  |   ... con pathspec amplio (., :/, *)        | deny    | ask                    |
  | reset --hard · clean -f                     | deny    | ask                    |
  | reset <ref> -- <paths>                      | deny    | allow / ask si amplio  |
  | stash (salvo list/show)                     | deny    | ask                    |
  | show · grep · diff · log · fetch · pull ... | allow   | allow                  |

La siembra de /adlc-build-loop (`git checkout <base> -- <archivos>` en el worktree) queda
permitida. Es una baranda, no un sandbox: `bash -c`, scripts y eval no se inspeccionan.
Ante cualquier error interno, deja pasar (fail-open) para no trabar la sesión.
"""
import json
import os
import re
import shlex
import subprocess
import sys

BROAD_PATHSPECS = {".", "./", ":/", ":/.", "*", ":(top)", ":(top)."}
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;"}
HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
FALLBACK_RE = re.compile(r"git\s.*\b(checkout|restore)\b[^\n]*\s--\s+(\.|:/|\*)(\s|$)")

ALT = ("Para LEER otra rama usa `git show <ref>:<path>`, `git grep <patrón> <ref>`, "
       "`git diff <a> <b>` o `git worktree add --detach /tmp/<x> <ref>`.")


def strip_heredocs(command):
    """Quita los cuerpos de heredoc (mensajes de commit, scripts) para no inspeccionar su texto."""
    out, lines, i = [], command.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = HEREDOC_RE.search(line)
        i += 1
        if m:
            delim = m.group(2)
            while i < len(lines) and lines[i].strip() != delim:
                i += 1
            i += 1  # salta el delimitador
    return "\n".join(out)


def segments(command):
    """Divide en comandos simples; los saltos de línea separan comandos."""
    lexer = shlex.shlex(strip_heredocs(command).replace("\n", " ; "), posix=True,
                        punctuation_chars=True)
    lexer.whitespace_split = True
    seg = []
    for tok in lexer:
        if tok in SEPARATORS:
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def git_out(args, cwd):
    try:
        r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=3)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def is_base(path):
    if not path or not os.path.isdir(path):
        return False
    git_dir = git_out(["rev-parse", "--path-format=absolute", "--git-dir"], path)
    common = git_out(["rev-parse", "--path-format=absolute", "--git-common-dir"], path)
    if not git_dir or not common or os.path.realpath(git_dir) != os.path.realpath(common):
        return False
    wts = git_out(["worktree", "list", "--porcelain"], path) or ""
    return sum(1 for l in wts.splitlines() if l.startswith("worktree ")) > 1


def classify(sub, args):
    """Devuelve (tipo, amplio) o None si la operación no escribe el árbol/index."""
    paths = args[args.index("--") + 1:] if "--" in args else []
    broad = any(p in BROAD_PATHSPECS for p in paths)
    if sub == "checkout" and "--" in args and paths:
        return ("checkout de paths", broad)
    if sub == "restore":
        pos = [a for a in args if not a.startswith("-")]
        return ("restore", broad or any(p in BROAD_PATHSPECS for p in pos))
    if sub == "read-tree":
        return ("read-tree", True)
    if sub == "reset":
        if "--hard" in args:
            return ("reset --hard", True)
        if paths:
            return ("reset de paths", broad)
    if sub == "clean" and any(a.startswith("-") and "f" in a and not a.startswith("--") for a in args):
        return ("clean -f", True)
    if sub == "clean" and "--force" in args:
        return ("clean -f", True)
    if sub == "stash":
        action = next((a for a in args if not a.startswith("-")), "push")
        if action not in ("list", "show"):
            return (f"stash {action}", True)
    return None


def inspect(command, cwd):
    """Devuelve (decisión, razón) de la operación más grave, o None."""
    worst = None
    cur = cwd
    for seg in segments(command):
        while seg and ("=" in seg[0] and not seg[0].startswith("-") or seg[0] in ("command", "time")):
            seg = seg[1:]
        if not seg:
            continue
        if seg[0] in ("cd", "pushd") and len(seg) > 1:
            cur = os.path.normpath(os.path.join(cur, os.path.expanduser(seg[1])))
            continue
        if seg[0] != "git":
            continue
        target, rest = cur, seg[1:]
        while rest and rest[0].startswith("-"):  # opciones globales: -C, -c, --no-pager...
            if rest[0] in ("-C", "-c") and len(rest) > 1:
                if rest[0] == "-C":
                    target = os.path.normpath(os.path.join(target, os.path.expanduser(rest[1])))
                rest = rest[2:]
            else:
                rest = rest[1:]
        if not rest:
            continue
        hit = classify(rest[0], rest[1:])
        if not hit:
            continue
        kind, broad = hit
        if is_base(target):
            decision = ("deny", f"`git {kind}` en la carpeta BASE `{target}` (solo lectura: "
                                f"fetch y pull --ff-only). {ALT} El trabajo va en su worktree.")
        elif broad:
            decision = ("ask", f"`git {kind}` con alcance amplio en `{target}`: sobrescribe "
                               f"árbol/index o la pila de stash compartida. {ALT}")
        else:
            continue
        if worst is None or (decision[0] == "deny" and worst[0] != "deny"):
            worst = decision
    return worst


def main():
    try:
        payload = json.load(sys.stdin)
        command = (payload.get("tool_input") or {}).get("command") or ""
        cwd = payload.get("cwd") or os.getcwd()
        if "git" not in command:
            return
        try:
            result = inspect(command, cwd)
        except ValueError:  # comillas desbalanceadas: red mínima por regex
            result = ("ask", f"No pude parsear el comando y parece un checkout amplio. {ALT}") \
                if FALLBACK_RE.search(command) else None
        if not result:
            return
        decision, reason = result
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": f"Guardrail git-base-guard: {reason}",
        }}, ensure_ascii=False))
    except Exception:
        return  # fail-open


if __name__ == "__main__":
    main()
