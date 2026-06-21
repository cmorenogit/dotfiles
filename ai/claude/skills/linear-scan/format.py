#!/usr/bin/env python3
"""Procesa el inbox de Linear (JSON por stdin) → tabla terminal en GMT-5.
Lo determinista del scan: filtra ventana, clasifica por type, colapsa por issue,
marca el delta vía cursor, sella la hora. El modelo solo dispara esto y muestra su salida.
Env: CURSOR_FILE, TZ_OFFSET, SINCE_OVERRIDE."""
import sys, os, json, re
from datetime import datetime, timezone, timedelta

def parse_iso(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))

raw = sys.stdin.read()
try:
    resp = json.loads(raw)
except Exception:
    sys.exit("✗ Respuesta de Linear no es JSON válido.")

if resp.get("errors"):
    sys.exit("✗ Linear devolvió errores: " + "; ".join(e.get("message", "?") for e in resp["errors"]))

nodes = ((resp.get("data") or {}).get("notifications") or {}).get("nodes") or []

tzoff = os.environ.get("TZ_OFFSET", "-05")
TZ = timezone(timedelta(hours=int(tzoff)))
now = datetime.now(timezone.utc)
cursor_file = os.environ["CURSOR_FILE"]
override = os.environ.get("SINCE_OVERRIDE", "").strip()

prev_cursor = None
try:
    with open(cursor_file) as f:
        prev_cursor = parse_iso(json.load(f)["last_scan_ts"])
except Exception:
    prev_cursor = None

def parse_dur(s):
    m = re.fullmatch(r"(\d+)\s*([hd])", s.strip())
    if not m:
        return None
    n, u = int(m.group(1)), m.group(2)
    return timedelta(hours=n) if u == "h" else timedelta(days=n)

peek = bool(override)   # --since => panorama: no avanza el cursor
if override:
    since = now - (parse_dur(override) or timedelta(days=3))
    since_label = f"últimas {override}"
elif prev_cursor:
    since, since_label = prev_cursor, "tu último scan"
else:
    since, since_label = now - timedelta(hours=24), "últimas 24h (primer scan)"

MENCION = {"issueMention", "issueCommentMention", "issueAssignedToYou"}
NOVEDAD = {"issueNewComment", "issueStatusChanged"}

def fmt_ago(dt):
    s = int((now - dt).total_seconds())
    if s < 3600:
        return f"hace {max(s // 60, 0)}m"
    if s < 86400:
        return f"hace {s // 3600}h"
    return f"hace {s // 86400}d"

issues, newest, oldest = {}, None, None
for n in nodes:
    created = parse_iso(n["createdAt"])
    newest = created if newest is None else max(newest, created)
    oldest = created if oldest is None else min(oldest, created)
    t = n.get("type")
    if t not in MENCION and t not in NOVEDAD:   # ruido (reacciones, borrados) fuera
        continue
    if created <= since:                          # ya visto / fuera de ventana
        continue
    iss = n.get("issue") or {}
    ident = iss.get("identifier")
    if not ident:
        continue
    asg = iss.get("assignee") or {}
    g = issues.setdefault(ident, {
        "ident": ident, "title": iss.get("title") or "",
        "state": (iss.get("state") or {}).get("name") or "",
        "resp": asg.get("name") or asg.get("displayName") or "—",
        "latest": created, "count": 0, "mencion": False,
    })
    g["count"] += 1
    g["latest"] = max(g["latest"], created)
    if t in MENCION:
        g["mencion"] = True

menciones = sorted((g for g in issues.values() if g["mencion"]), key=lambda g: g["latest"], reverse=True)
novedad = sorted((g for g in issues.values() if not g["mencion"]), key=lambda g: g["latest"], reverse=True)

def trunc(s, n=46):
    s = " ".join(s.split())
    return s if len(s) <= n else s[:n - 1] + "…"

def row(g):
    hhmm = g["latest"].astimezone(TZ).strftime("%H:%M")
    cnt = f" ×{g['count']}" if g["count"] > 1 else ""
    return f"  {g['ident']:<9} {trunc(g['title'], 42):<42} {g['state']:<12} {trunc(g['resp'], 10):<10} {fmt_ago(g['latest']):>8} ({hhmm} {tzoff}){cnt}"

out = []
if menciones:
    out.append(f"🔔 Te mencionan / asignan — desde {since_label}")
    out += [row(g) for g in menciones]
    out.append("")
if novedad:
    out.append(f"📋 Novedad en tus issues — desde {since_label}")
    out += [row(g) for g in novedad]
    out.append("")
if not menciones and not novedad:
    out.append(f"✓ Sin novedades desde {since_label}.")
if len(nodes) >= 150 and oldest is not None and oldest > since:
    out.append("(aviso: tope 150 corta dentro de la ventana — puede faltar lo más viejo; usá --since más corto)")
out.append(f"— foto al {now.astimezone(TZ).strftime('%H:%M')} {tzoff} · caduca: re-corré para lo posterior")
print("\n".join(out))

if not peek and newest is not None:
    try:
        with open(cursor_file, "w") as f:
            json.dump({"last_scan_ts": newest.isoformat().replace("+00:00", "Z")}, f)
    except Exception as e:
        print(f"(aviso: no pude guardar el cursor: {e})", file=sys.stderr)
