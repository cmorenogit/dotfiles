#!/usr/bin/env python3
"""Procesa UN issue de Linear (JSON por stdin) → issue + hilo COMPLETO para análisis, en GMT-5.
Determinista: header + descripción completa + cada comentario con su comment_id (linear-lore cita
comment_id), ordenado por createdAt asc (NO confiamos en el orden de Linear). No interpreta nada
(eso lo hace el agente de /linear-lore). Env: TZ_OFFSET, ID (identifier pedido)."""
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

def clean(s):
    """Colapsa runs de líneas en blanco; deja el resto del markdown tal cual (verbatim legible)."""
    s = (s or "").replace("\r\n", "\n").strip()
    return re.sub(r"\n{3,}", "\n\n", s)

ident = iss.get("identifier") or asked
title = " ".join((iss.get("title") or "").split())
state = (iss.get("state") or {}).get("name") or "—"
asg = iss.get("assignee") or {}
resp_name = asg.get("displayName") or asg.get("name") or "sin asignar"
url = iss.get("url") or ""
desc = clean(iss.get("description") or "")

cdata = iss.get("comments") or {}
allc = (cdata.get("nodes")) or []
for c in allc:
    c["_ts"] = parse_iso(c["createdAt"])
allc.sort(key=lambda c: c["_ts"])                              # createdAt asc — nuestro orden, no el de Linear

def author(c):
    cu = c.get("user") or {}
    return cu.get("displayName") or cu.get("name") or "?"

out = []
out.append(f"{ident} · {title}")
out.append(f"{state} · {resp_name}" + (f" · {url}" if url else ""))
out.append("")

if desc:
    out += ["Descripción:", desc, ""]

if allc:
    n = len(allc)
    out.append(f"────────── {n} comentario{'s' if n != 1 else ''} · hilo completo · viejo → nuevo ──────────")
    for i, c in enumerate(allc):
        when = c["_ts"].astimezone(TZ).strftime("%d/%m %H:%M")
        reply = "↳ " if c.get("parent") else ""
        tag = "  ← más reciente" if i == n - 1 else ""
        out.append("")
        out.append(f"[{when} {tzoff}] {reply}{author(c)}  ·  comment_id: {c.get('id', '?')}{tag}")
        out.append(clean(c.get("body") or "") or "(comentario vacío)")
    if (cdata.get("pageInfo") or {}).get("hasNextPage"):
        out += ["", "⚠ hilo >100 comentarios: hay más sin traer (paginá si el contexto lo exige)."]
else:
    out.append("(sin comentarios todavía)")

out.append("")
out.append(f"— fuente: Linear GraphQL API (live) · a fondo lo analiza /linear-lore · {ident}")
print("\n".join(out))
