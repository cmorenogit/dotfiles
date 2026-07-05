#!/usr/bin/env python3
"""
preview-db - acceso REST (service_role) a la BD de un preview de Beat.
Resuelve tag pr-<N> -> revision Cloud Run -> URL + service_role -> request.
Solo previews (aborta si la URL no es pr-N---preview-rr). Writes hacen DRY-RUN salvo --confirm.

Uso:
  preview_db.py list
  preview_db.py <PR> tables [filtro]
  preview_db.py <PR> get    <tabla> [querystring]
  preview_db.py <PR> count  <tabla> [querystring]
  preview_db.py <PR> patch  <tabla> <filtro-querystring> <json>  [--confirm]
  preview_db.py <PR> post   <tabla> <json>                        [--confirm]
  preview_db.py <PR> delete <tabla> <filtro-querystring>          [--confirm]

Requiere: gcloud logueado (lee la config del Cloud Run 'preview-rr').
Fuera de scope: RPC, auth admin y storage (existen pero esta skill no los expone).
"""
import sys, json, ssl, re, subprocess, urllib.request, urllib.error

PROJECT = "desarrolo-productos"
REGION = "us-central1"
SERVICE = "preview-rr"
PREVIEW_URL_RE = re.compile(r"^https://pr-\d+---preview-rr-", re.I)


def sh_json(args):
    o = subprocess.run(args, capture_output=True, text=True)
    if o.returncode != 0:
        sys.exit("gcloud error: " + o.stderr.strip()[:300])
    return json.loads(o.stdout)


def traffic():
    svc = sh_json(["gcloud", "run", "services", "describe", SERVICE,
                   "--region", REGION, "--project", PROJECT, "--format=json"])
    return [(t.get("tag"), t.get("revisionName"))
            for t in svc.get("status", {}).get("traffic", []) if t.get("tag")]


def cmd_list():
    print("Previews vivos (servicio %s):" % SERVICE)
    for tag, rev in sorted(traffic()):
        print("  %-10s -> %s" % (tag, rev))


def resolve(pr):
    tag = pr if str(pr).startswith("pr-") else "pr-" + str(pr)
    for t, rev in traffic():
        if t == tag:
            return tag, rev
    sys.exit("No hay tag %s vivo. Corre 'list' para ver los previews activos "
             "(el PR necesita el label deploy:preview)." % tag)


def env_of(rev):
    j = sh_json(["gcloud", "run", "revisions", "describe", rev,
                 "--region", REGION, "--project", PROJECT, "--format=json"])
    env = {}

    def rec(o):
        if isinstance(o, dict):
            if isinstance(o.get("containers"), list):
                for c in o["containers"]:
                    for e in (c.get("env", []) or []):
                        n = e.get("name")
                        if n and n not in env and "value" in e:
                            env[n] = e["value"]
            for v in o.values():
                rec(v)
        elif isinstance(o, list):
            for v in o:
                rec(v)
    rec(j)
    return env


def endpoint(pr):
    tag, rev = resolve(pr)
    env = env_of(rev)
    url = env.get("SUPABASE_PUBLIC_URL") or env.get("API_EXTERNAL_URL")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("No pude extraer URL/service_role de %s" % rev)
    if not PREVIEW_URL_RE.match(url):
        sys.exit("GUARDA: la URL '%s' no parece un preview (pr-N---preview-rr). Abortado." % url)
    print("preview %s -> rev %s" % (tag, rev))
    print("URL %s | service_role %s (redactado)" % (url, key[:4] + "..." + key[-4:]))
    return url.rstrip("/"), key


def request(url, key, path, method="GET", body=None, extra=None):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    h = {"apikey": key, "Authorization": "Bearer " + key, "Accept": "application/json"}
    if body is not None:
        h["Content-Type"] = "application/json"
        h["Prefer"] = "return=representation"
    if extra:
        h.update(extra)
    data = body.encode() if isinstance(body, str) else body
    r = urllib.request.Request(url + path, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=25, context=ctx) as resp:
            return resp.status, {k.lower(): v for k, v in resp.headers.items()}, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read().decode("utf-8", "replace")


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "list":
        return cmd_list()

    pr, action, rest = a[0], a[1], a[2:]
    confirm = "--confirm" in rest
    rest = [x for x in rest if x != "--confirm"]
    url, key = endpoint(pr)
    print("-" * 60)

    if action == "tables":
        s, h, b = request(url, key, "/rest/v1/")
        defs = sorted((json.loads(b).get("definitions") or {}).keys())
        flt = rest[0].lower() if rest else None
        if flt:
            defs = [d for d in defs if flt in d.lower()]
        print("HTTP %s | tablas/vistas: %d%s" % (s, len(defs), (" (match '%s')" % flt) if flt else ""))
        for d in defs:
            print("  -", d)

    elif action == "count":
        table = rest[0]
        query = rest[1] if len(rest) > 1 else "select=*"
        s, h, b = request(url, key, "/rest/v1/%s?%s" % (table, query),
                          extra={"Prefer": "count=exact", "Range": "0-0"})
        print("HTTP %s | Content-Range: %s" % (s, h.get("content-range")))

    elif action == "get":
        table = rest[0]
        query = rest[1] if len(rest) > 1 else ""
        s, h, b = request(url, key, "/rest/v1/%s%s" % (table, ("?" + query) if query else ""))
        print("HTTP %s" % s)
        print(b[:2000])

    elif action in ("patch", "post", "delete"):
        if action == "patch":
            table, filt, jbody = rest[0], rest[1], rest[2]
            path, body = "/rest/v1/%s?%s" % (table, filt), jbody
        elif action == "post":
            table, jbody = rest[0], rest[1]
            path, body = "/rest/v1/%s" % table, jbody
        else:  # delete
            table, filt = rest[0], rest[1]
            path, body = "/rest/v1/%s?%s" % (table, filt), None
        if not confirm:
            print("DRY-RUN (sin --confirm): NO se ejecuto.")
            print("  %s %s" % (action.upper(), path))
            if body is not None:
                print("  body: %s" % body)
            print("Confirma el cambio con Cesar, luego re-corre con --confirm.")
            return
        s, h, b = request(url, key, path, method=action.upper(), body=body,
                          extra={"Prefer": "return=representation"})
        print("HTTP %s" % s)
        print(b[:1500])
    else:
        sys.exit("accion desconocida: %s\n%s" % (action, __doc__))


if __name__ == "__main__":
    main()
