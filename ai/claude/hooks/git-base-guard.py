#!/usr/bin/env python3
"""Git base guard (PreToolUse/Bash).

Evita que una sesión escriba el árbol de trabajo de una carpeta BASE usando git para "leer"
otra rama. Incidente 15/16-sep-2026: dos sesiones con cwd en el vault corrieron
`cd back-pulse-cesar && git checkout -q <ref> -- .` y dejaron 746 archivos del padre staged
sobre `main` (HEAD no se movió, así que el reflog no lo mostró).

BASE = worktree principal de un repo (git-dir == git-common-dir) que tiene >=1 worktree
vinculado. Genérico: cubre Beat y cualquier repo futuro sin listas.

Política (binaria en worktrees: en modo bypass un "ask" se auto-aprueba, así que no se usa
donde importa — medido 2026-09-25 sobre 30 días de sesiones Beat):
  | operación                                        | en BASE | en worktree |
  |--------------------------------------------------|---------|-------------|
  | checkout -- <archivo> / restore <archivo>        | deny    | allow       |
  | checkout/restore con pathspec amplio (., :/, *)  | deny    | deny        |
  | stash a secas · stash push sin paths · pop ·     | deny    | deny        |
  |   clear · apply/drop sin ref (cima compartida)   |         |             |
  | stash push … -- <paths> · apply/drop <ref>       | deny    | allow       |
  | reset --hard (sincronizar con la rama remota)    | deny    | allow       |
  | reset <ref> -- <paths>                           | deny    | allow/deny si amplio |
  | read-tree · clean -f                             | deny    | ask         |
  | show · grep · diff · log · fetch · pull ...      | allow   | allow       |

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
    """Devuelve (tipo, nivel_en_worktree) si la operación escribe árbol/index/stash; si no, None.

    nivel_en_worktree ∈ {None (allow), "ask", "deny"}. En una BASE todo lo clasificado es deny.
    """
    paths = args[args.index("--") + 1:] if "--" in args else []
    broad = any(p in BROAD_PATHSPECS for p in paths)
    if sub == "checkout" and "--" in args and paths:
        return ("checkout de paths", "deny" if broad else None)
    if sub == "restore":
        pos = [a for a in args if not a.startswith("-")]
        wide = broad or any(p in BROAD_PATHSPECS for p in pos)
        return ("restore", "deny" if wide else None)
    if sub == "read-tree":
        return ("read-tree", "ask")
    if sub == "reset":
        if "--hard" in args:
            return ("reset --hard", None)
        if paths:
            return ("reset de paths", "deny" if broad else None)
    if sub == "clean" and ("--force" in args or any(
            a.startswith("-") and not a.startswith("--") and "f" in a for a in args)):
        return ("clean -f", "ask")
    if sub == "stash":
        pos = [a for a in args if not a.startswith("-")]
        action = pos[0] if pos else "push"
        if action in ("list", "show", "create", "store"):
            return None
        if action in ("push", "save"):
            ok = bool(paths) and not broad
            return (f"stash {action}" + ("" if ok else " sin paths"), None if ok else "deny")
        if action in ("apply", "drop", "branch"):
            has_ref = len(pos) > 1
            return (f"stash {action}" + ("" if has_ref else " sin ref"), None if has_ref else "deny")
        return (f"stash {action}", "deny")  # pop, clear y cualquier otra: cima de la pila compartida
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
        kind, level = hit
        if is_base(target):
            decision = ("deny", f"`git {kind}` en la carpeta BASE `{target}` (solo lectura: "
                                f"fetch y pull --ff-only). {ALT} El trabajo va en su worktree.")
        elif level:
            decision = (level, f"`git {kind}` en `{target}`: sobrescribe el árbol/index con alcance "
                               f"amplio o toca la cima de la pila de stash, compartida entre "
                               f"worktrees. {ALT} Para stash, usa `stash push -m <msg> -- <paths>` "
                               f"y `stash apply/drop <ref>` explícitos.")
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
