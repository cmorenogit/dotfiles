#!/usr/bin/env python3
"""transcripcion.py — motor determinista de la skill /transcripcion.

Busca y extrae el VERBATIM (pestaña "Transcripción") de reuniones de Google Meet
vía el CLI `gws`. El modelo interpreta la query en lenguaje natural y llama a este
script con parámetros concretos; el script hace lo mecánico y NUNCA se equivoca en
las dos cosas que rompían el flujo manual:

  1. Pasa includeTabsContent=true y recorre tabs[] -> documentTab.body.
     (Sin esto, la API devuelve solo la pestaña "Las notas" = el resumen.)
  2. Filtra el ruido "Using keyring backend: ..." que gws imprime antes del JSON.

Scope de búsqueda: GLOBAL (incluye shared-with-me), no una carpeta. Los weeklies
y reuniones grupales son owned por otra persona (Ignacio/Nicole) y solo aparecen
con búsqueda global.

Subcomandos:
  list  --name TXT --after YYYY-MM-DD --before YYYY-MM-DD --limit N
        -> JSON {count, candidates:[{id,title,owner,date,time,tz}]}
  get   DOC_ID
        -> JSON {path,title,owner,date,duration,turns,chars,tab} y escribe /tmp/*.md
"""
import sys, json, subprocess, re, argparse, datetime, unicodedata, os

TZ_OFFSETS = {  # offset del huso respecto a UTC para las TZ con nombre de los títulos
    "WEST": 1,   # Western European Summer Time = UTC+1
    "WET": 0,    # Western European Time = UTC+0
}
TARGET_OFFSET = -5  # GMT-5 (preferencia de César)

# GMT±HH:MM primero en el alternation para no capturar solo "GMT"
DATE_RE = re.compile(r"(\d{4})/(\d{2})/(\d{2})(?:\s+(\d{1,2}):(\d{2}))?\s*(GMT[+-]\d{2}:\d{2}|[A-Z]{3,4})?")
DUR_RE = re.compile(r"finaliz\w*\s+despu\w*s\s+de\s+(\d{1,2}:\d{2}:\d{2})", re.IGNORECASE)
TS_RE = re.compile(r"\b(\d{1,2}:\d{2}:\d{2})\b")
SPEAKER_RE = re.compile(r"^[A-ZÁÉÍÓÚÑ][\wÁÉÍÓÚÑáéíóúñ.'\- ]{1,38}:\s", re.MULTILINE)


def gws(args):
    """Corre gws y devuelve stdout sin el ruido previo al JSON."""
    p = subprocess.run(["gws"] + args, capture_output=True, text=True)
    lines = p.stdout.splitlines()
    start = 0
    for i, l in enumerate(lines):
        s = l.lstrip()
        if s.startswith("{") or s.startswith("["):
            start = i
            break
    return "\n".join(lines[start:]), p.stderr


def drive_list(query, fields, limit=200):
    params = {
        "q": query, "pageSize": min(limit, 1000), "fields": fields,
        "orderBy": "modifiedTime desc",
        "includeItemsFromAllDrives": True, "supportsAllDrives": True,
    }
    out, err = gws(["drive", "files", "list", "--params", json.dumps(params)])
    try:
        return json.loads(out).get("files", [])
    except Exception:
        return []


def parse_title(name):
    """Extrae fecha/hora/tz de la reunión desde el título, normaliza hora a GMT-5."""
    m = DATE_RE.search(name)
    if not m:
        return {"date": None, "time": None, "tz": None}
    y, mo, d, hh, mm, tz = m.groups()
    date = f"{y}-{mo}-{d}"
    time_out, tz_out = None, tz
    if hh is not None:
        # convertir a GMT-5 si conocemos el offset de origen
        src = None
        if tz and tz.startswith("GMT") and len(tz) >= 9:
            sign = 1 if tz[3] == "+" else -1
            src = sign * int(tz[4:6])
        elif tz in TZ_OFFSETS:
            src = TZ_OFFSETS[tz]  # offset del huso respecto a UTC
        if src is not None:
            try:
                dt = datetime.datetime(int(y), int(mo), int(d), int(hh), int(mm),
                                       tzinfo=datetime.timezone(datetime.timedelta(hours=src)))
                dt5 = dt.astimezone(datetime.timezone(datetime.timedelta(hours=TARGET_OFFSET)))
                date = dt5.strftime("%Y-%m-%d")
                time_out = dt5.strftime("%H:%M")
                tz_out = "GMT-5"
            except Exception:
                time_out = f"{hh}:{mm}"
        else:
            time_out = f"{hh}:{mm}"
    return {"date": date, "time": time_out, "tz": tz_out}


def clean_title(name):
    """Quita los sufijos de Gemini para mostrar el título legible."""
    n = re.sub(r"\s*-?\s*(Notas de Gemini|Transcript).*$", "", name).strip(" -:")
    n = re.split(r"\s*:?\s*\d{4}/\d{2}/\d{2}", n)[0].strip(" -:/")
    return n or name


def cmd_list(a):
    terms = ['(name contains "Notas de Gemini" or name contains "Transcript")',
             'mimeType="application/vnd.google-apps.document"']
    if a.name:
        terms.append(f'name contains "{a.name}"')
    q = " and ".join(terms)
    files = drive_list(q, "files(id,name,owners(displayName),modifiedTime)", limit=200)
    cands = []
    seen = set()
    for f in files:
        meta = parse_title(f["name"])
        date = meta["date"]
        if a.after and (not date or date < a.after):
            continue
        if a.before and (not date or date > a.before):
            continue
        key = (clean_title(f["name"]), date)
        if key in seen:  # colapsa el par Notas/Transcript del mismo evento
            continue
        seen.add(key)
        owner = (f.get("owners") or [{}])[0].get("displayName", "?")
        cands.append({"id": f["id"], "title": clean_title(f["name"]),
                      "owner": owner, "date": date, "time": meta["time"], "tz": meta["tz"]})
    cands.sort(key=lambda c: (c["date"] or "", c["time"] or ""), reverse=True)
    cands = cands[: a.limit]
    print(json.dumps({"count": len(cands), "candidates": cands}, ensure_ascii=False, indent=2))


def extract_body(body):
    out = []
    for el in body.get("content", []):
        if "paragraph" in el:
            for e in el["paragraph"].get("elements", []):
                out.append(e.get("textRun", {}).get("content", ""))
    return "".join(out)


def walk_tabs(tabs):
    res = []
    for t in tabs:
        title = t.get("tabProperties", {}).get("title", "")
        res.append((title, extract_body(t.get("documentTab", {}).get("body", {}))))
        res += walk_tabs(t.get("childTabs", []))
    return res


def slugify(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^\w\s-]", "", s).strip().lower()
    return re.sub(r"[\s_-]+", "-", s)[:50] or "transcripcion"


def cmd_get(a):
    params = {"documentId": a.doc_id, "includeTabsContent": True}
    out, err = gws(["docs", "documents", "get", "--params", json.dumps(params)])
    try:
        doc = json.loads(out)
    except Exception:
        print(json.dumps({"error": "no se pudo leer el doc", "stderr": err[:300]}))
        sys.exit(1)
    title = doc.get("title", "?")
    tabs = walk_tabs(doc.get("tabs", []))
    if not tabs:  # doc legacy sin tabs
        tabs = [("(body)", extract_body(doc.get("body", {})))]
    # elegir la pestaña de transcripción; fallback a la más larga
    verb = next((txt for tt, txt in tabs if "ranscrip" in tt.lower()), None)
    used = "Transcripción"
    if verb is None:
        used, verb = max(tabs, key=lambda x: len(x[1]))
        used = f"{used} (sin pestaña Transcripción)"
    meta = parse_title(title)
    dur = DUR_RE.search(verb)
    if dur:
        duration = dur.group(1)
    else:
        ts = TS_RE.findall(verb)
        duration = ts[-1] if ts else "?"
    turns = len(SPEAKER_RE.findall(verb))
    fname = f"transcripcion-{meta['date'] or 'sf'}-{slugify(clean_title(title))}.md"
    path = os.path.join("/tmp", fname)
    header = (f"# {clean_title(title)}\n\n"
              f"- Fecha: {meta['date']} {meta['time'] or ''} {meta['tz'] or ''}\n"
              f"- Doc: https://docs.google.com/document/d/{a.doc_id}/edit\n"
              f"- Pestaña: {used} · {len(verb)} chars · ~{turns} turnos · duración {duration}\n\n---\n\n")
    with open(path, "w") as fh:
        fh.write(header + verb)
    print(json.dumps({"path": path, "title": clean_title(title), "date": meta["date"],
                      "time": meta["time"], "tz": meta["tz"], "duration": duration,
                      "turns": turns, "chars": len(verb), "tab": used},
                     ensure_ascii=False, indent=2))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("list")
    pl.add_argument("--name", default=None)
    pl.add_argument("--after", default=None)   # YYYY-MM-DD inclusive
    pl.add_argument("--before", default=None)  # YYYY-MM-DD inclusive
    pl.add_argument("--limit", type=int, default=12)
    pl.set_defaults(func=cmd_list)
    pg = sub.add_parser("get")
    pg.add_argument("doc_id")
    pg.set_defaults(func=cmd_get)
    a = ap.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
