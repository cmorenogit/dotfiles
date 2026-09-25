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

Además (análisis de 212 sesiones Beat, 25-sep-2026):
  - worktree: `git checkout <ref> -- <paths>` sobre archivos con cambios SIN commitear → deny
    (RYR-287: revertir una siembra borró el fix entero).
  - worktree: cambiar de rama (switch / checkout <rama> / -b) con cambios trackeados → deny
    (RYR-298: dos implementadores en el mismo worktree mezclaron el WIP entre subPRs).
  - supabase: `db push`, `functions deploy`, `link`, `secrets set` → deny siempre (remoto = CI/Hakeem);
    `db reset`, `start`, `stop`, `migration up`, `functions serve` → deny en la BASE y en un
    worktree sin `.worktree-slot` (correría sobre el stack de la base).
  - gh pr merge: deny si la base es main (lo mergea Hakeem), si usa --squash (subPR→trunk va con --merge)
    o si el PR tiene checks pendientes o en rojo (el merge al trunk lo valida ADLC + CI).
  - gh pr create hacia main en apprecio-pulse sin los 3 labels del preview → deny (usar beat-promote.sh);
    quitar deploy:preview/deploy:staging de un PR → deny (destruye el preview / saltea tests).
  - preview_db.py … --confirm: deny (la escritura en un preview la corre César con `!`).

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


def toplevel(path):
    return git_out(["rev-parse", "--show-toplevel"], path)


def dirty_tracked(path, paths=None):
    """True si hay cambios trackeados sin commitear (en todo el árbol o en `paths`)."""
    args = ["status", "--porcelain", "--untracked-files=no"] + (["--", *paths] if paths else [])
    out = git_out(args, path)
    return bool(out)


def supabase_rule(args, target):
    sub = " ".join(a for a in args if not a.startswith("-"))[:40]
    remote = ("db push", "functions deploy", "link", "secrets set", "db remote")
    local = ("db reset", "start", "stop", "migration up", "functions serve")
    if any(sub.startswith(r) for r in remote):
        return ("deny", f"`supabase {sub}` toca un proyecto REMOTO: los deploys y el link los hace CI/Hakeem, nunca una sesión local.")
    if any(sub.startswith(r) for r in local):
        top = toplevel(target) or target
        if is_base(top):
            return ("deny", f"`supabase {sub}` en la BASE `{top}` opera el stack de la base. Para analizar otra rama usá su worktree o `git show origin/<rama>:<path>`.")
        if not os.path.isfile(os.path.join(top, ".worktree-slot")) and os.path.isdir(os.path.join(top, "supabase")):
            return ("deny", f"`supabase {sub}` en `{top}` sin `.worktree-slot`: el worktree no está aislado y correría sobre el stack de la base. Corré `~/.config/worktrunk/scripts/beat-isolate.sh` primero.")
    return None


REQUIRED_PREVIEW_LABELS = ("deploy:staging", "deploy:preview", "skip:e2e")


def _gh_opts(rest):
    """Separa -R/--repo, las etiquetas (--label/-l, admite coma) y el primer posicional."""
    repo, num, labels, remove, base, i = None, None, [], [], None, 0
    while i < len(rest):
        a = rest[i]
        nxt = rest[i + 1] if i + 1 < len(rest) else ""
        if a in ("-R", "--repo"):
            repo = nxt; i += 2; continue
        if a in ("-l", "--label", "--add-label"):
            labels += nxt.split(","); i += 2; continue
        if a.startswith("--label=") or a.startswith("--add-label="):
            labels += a.split("=", 1)[1].split(","); i += 1; continue
        if a == "--remove-label":
            remove += nxt.split(","); i += 2; continue
        if a.startswith("--remove-label="):
            remove += a.split("=", 1)[1].split(","); i += 1; continue
        if a in ("-B", "--base"):
            base = nxt; i += 2; continue
        if a.startswith("--base="):
            base = a.split("=", 1)[1]; i += 1; continue
        if not a.startswith("-") and num is None:
            num = a
        i += 1
    return repo, num, labels, remove, base


def _is_back_repo(repo, target):
    if repo:
        return repo.endswith("apprecio-pulse")
    return "apprecio-pulse" in (git_out(["config", "--get", "remote.origin.url"], target) or "")


def gh_rule(args, target):
    """Reglas de `gh pr create|edit|merge` (labels del preview y merge validado)."""
    if len(args) < 2 or args[0] != "pr":
        return None
    sub, rest = args[1], args[2:]
    repo, num, labels, remove, base = _gh_opts(rest)
    if sub == "create" and base == "main" and _is_back_repo(repo, target):
        missing = [l for l in REQUIRED_PREVIEW_LABELS if l not in labels]
        if missing:
            return ("deny", f"PR hacia main sin {', '.join(missing)}: el preview necesita los 3 labels JUNTOS "
                            f"(deploy:staging corre backend-tests; sin él se omiten errores). Usá "
                            f"`bash ~/.config/worktrunk/scripts/beat-promote.sh --title … --body …`.")
    if sub == "edit" and any(l in ("deploy:preview", "deploy:staging") for l in remove):
        return ("deny", "Quitar deploy:preview/deploy:staging de un PR abierto DESTRUYE el preview o saltea los tests. Si de verdad hace falta, lo hace César con `!`.")
    if sub != "merge":
        return None
    if "--squash" in rest or "-s" in rest:
        return ("deny", "`gh pr merge --squash`: los subPR → trunk se mergean con `--merge` (regla de César, 08-sep); trunk → main lo mergea Hakeem.")
    view = ["gh", "pr", "view"] + ([num] if num else []) + (["-R", repo] if repo else []) + ["--json", "baseRefName", "-q", ".baseRefName"]
    try:
        base_ref = subprocess.run(view, cwd=target, capture_output=True, text=True, timeout=6).stdout.strip()
    except Exception:
        base_ref = ""
    if base_ref == "main":
        return ("deny", "`gh pr merge` hacia main: el merge y deploy a main lo hace Hakeem, nunca una sesión.")
    checks = ["gh", "pr", "checks"] + ([num] if num else []) + (["-R", repo] if repo else [])
    try:
        rc = subprocess.run(checks, cwd=target, capture_output=True, text=True, timeout=8).returncode
    except Exception:
        rc = 0  # sin red: no bloquear por no poder verificar
    if rc == 8:
        return ("deny", "CI todavía corre en ese PR: el merge al trunk se hace con todos los checks en verde y tras `/adlc-pre-merge` sin bloqueantes.")
    if rc not in (0, 8):
        return ("deny", "Hay checks en ROJO en ese PR: no se mergea al trunk. Revisá `gh pr checks`, corregí y re-corré `/adlc-pre-merge`.")
    return None

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
        tool = os.path.basename(seg[0])
        if tool == "npx" and len(seg) > 1 and seg[1] == "supabase":
            tool, seg = "supabase", seg[1:]
        if tool == "supabase":
            hit = supabase_rule(seg[1:], cur)
            if hit and (worst is None or worst[0] != "deny"):
                worst = hit
            continue
        if tool == "gh":
            hit = gh_rule(seg[1:], cur)
            if hit:
                worst = hit
            continue
        if any("preview_db.py" in t for t in seg) and "--confirm" in seg:
            worst = ("deny", "`preview_db.py … --confirm` escribe en la BD de un preview: mostrá el dry-run y que César lo corra con `!`.")
            continue
        if tool != "git":
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
        sub, sargs = rest[0], rest[1:]
        # Reglas que dependen del estado del worktree (solo fuera de la base).
        if not is_base(target):
            if sub == "checkout" and "--" in sargs:
                before = [a for a in sargs[:sargs.index("--")] if not a.startswith("-")]
                paths = [p for p in sargs[sargs.index("--") + 1:] if p not in BROAD_PATHSPECS]
                if before and paths and dirty_tracked(target, paths):
                    worst = ("deny", f"`git checkout {before[0]} -- …` sobre archivos con cambios SIN commitear en `{target}`: se pierden. Commiteá primero (o `cp` de respaldo) y recién ahí siembra/revierte.")
                    continue
            switching = (sub == "switch" and any(not a.startswith("-") for a in sargs)) or \
                        (sub == "checkout" and "--" not in sargs and any(not a.startswith("-") for a in sargs))
            if switching and dirty_tracked(target):
                worst = ("deny", f"Cambio de rama en `{target}` con cambios trackeados sin commitear: el WIP viajaría a la otra rama. Commiteá antes de cambiar: los subPRs se trabajan de a uno en este worktree (dos implementadores en paralelo sobre el mismo árbol mezclan el trabajo, RYR-298).")
                continue
        hit = classify(sub, sargs)
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
        if not any(k in command for k in ("git", "supabase", "gh ", "preview_db")):
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
