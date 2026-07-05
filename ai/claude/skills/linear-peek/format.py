#!/usr/bin/env python3
"""Procesa UN issue de Linear (JSON por stdin) → comentarios de una VENTANA de tiempo, en GMT-5.
Determinista: header de contexto + cuerpo COMPLETO de cada comentario, ordenado por createdAt (NO
confiamos en el orden de Linear, que viene por updatedAt). No interpreta nada (eso es /linear-lore).
Env: TZ_OFFSET, ID (identifier pedido), PEEK_WINDOW (''=hoy · Nd · Nh · all)."""
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

nodes = (((resp.get("data") or {}).get("issues") or {}).get("nodes")) or []
asked = os.environ.get("ID", "el issue")
if not nodes:
    sys.exit(f"✗ No encontré {asked} (¿ID correcto? ¿tenés acceso a ese team?).")

iss = nodes[0]
tzoff = os.environ.get("TZ_OFFSET", "-05")
TZ = timezone(timedelta(hours=int(tzoff)))
now = datetime.now(timezone.utc)

def clean(s):
    """Colapsa runs de líneas en blanco; deja el resto del markdown tal cual (verbatim legible)."""
    s = (s or "").replace("\r\n", "\n").strip()
    return re.sub(r"\n{3,}", "\n\n", s)

def fmt_ago(dt):
    s = int((now - dt).total_seconds())
    if s < 3600:  return f"hace {max(s // 60, 0)}m"
    if s < 86400: return f"hace {s // 3600}h"
    return f"hace {s // 86400}d"

def resolve_window(spec):
    """spec → (since_utc | None, etiqueta, aviso|None)."""
    spec = (spec or "").strip().lower()
    if spec in ("", "today", "hoy"):
        midnight = now.astimezone(TZ).replace(hour=0, minute=0, second=0, microsecond=0)
        return midnight.astimezone(timezone.utc), "hoy", None
    if spec in ("all", "todo", "*"):
        return None, "todo el hilo", None
    m = re.fullmatch(r"(\d+)\s*([hd])", spec)
    if m:
        n, u = int(m.group(1)), m.group(2)
        return now - (timedelta(hours=n) if u == "h" else timedelta(days=n)), f"últimas {spec}", None
    midnight = now.astimezone(TZ).replace(hour=0, minute=0, second=0, microsecond=0)
    return midnight.astimezone(timezone.utc), "hoy", f"(ventana '{spec}' no reconocida; muestro hoy — usá Nd / Nh / all)"

since, label, warn = resolve_window(os.environ.get("PEEK_WINDOW", ""))

ident = iss.get("identifier") or asked
title = " ".join((iss.get("title") or "").split())
state = (iss.get("state") or {}).get("name") or "—"
asg = iss.get("assignee") or {}
resp_name = asg.get("displayName") or asg.get("name") or "sin asignar"
url = iss.get("url") or ""
desc = clean(iss.get("description") or "")

allc = ((iss.get("comments") or {}).get("nodes")) or []
for c in allc:
    c["_ts"] = parse_iso(c["createdAt"])
allc.sort(key=lambda c: c["_ts"])                              # createdAt asc — nuestro orden, no el de Linear
shown = [c for c in allc if since is None or c["_ts"] >= since]

def author(c):
    cu = c.get("user") or {}
    return cu.get("displayName") or cu.get("name") or "?"

def block(c, tag=""):
    when = c["_ts"].astimezone(TZ).strftime("%d/%m %H:%M")
    reply = "↳ " if c.get("parent") else ""
    return [f"[{when} {tzoff}] {reply}{author(c)}{tag}", clean(c.get("body") or "") or "(comentario vacío)"]

out = []
out.append(f"{ident} · {title}")
out.append(f"{state} · {resp_name}" + (f" · {url}" if url else ""))
if warn:
    out.append(warn)
out.append("")

if desc:
    short = desc if len(desc) <= 320 else desc[:319] + "…"
    out += ["Descripción:", short, ""]

if shown:
    n = len(shown)
    out.append(f"────────── {n} comentario{'s' if n != 1 else ''} · {label} · viejo → nuevo ──────────")
    for i, c in enumerate(shown):
        out.append("")
        out += block(c, tag="  ← más reciente" if i == n - 1 else "")
elif allc:
    last = allc[-1]
    out.append(f"(sin comentarios en «{label}». El último fue {fmt_ago(last['_ts'])}:)")
    out.append("")
    out += block(last)
    out.append("")
    out.append(f"↑ ampliá la ventana: /linear-peek {ident} 7d   (o all)")
else:
    out.append("(sin comentarios todavía)")

out.append("")
out.append(f"— peek al {now.astimezone(TZ).strftime('%H:%M')} {tzoff} · a fondo → /linear-lore {ident}")
print("\n".join(out))
