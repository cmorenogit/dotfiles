#!/usr/bin/env python3
"""fetch.py — extractor determinista de /learn.

Dado un URL: detecta la fuente, extrae metadata y la transcripción FUENTE.
Imprime JSON a stdout. La parte interpretativa (destilar, criticar, vincular)
la hace el modelo en SKILL.md; este script solo hace lo mecánico y reproducible.

Fuentes:
  youtube / tiktok / instagram -> yt-dlp descarga audio + mlx_whisper SIEMPRE
                                  (calidad > velocidad); subtítulos solo como
                                  fallback si whisper falla o no está.
                                  Instagram suele exigir login: best-effort.
  twitter / x                  -> texto + metadata vía el endpoint de
                                  syndication de X (token calculado); si el
                                  tweet trae video, además yt-dlp + whisper
                                  combinados. X Articles: se renderiza el
                                  cuerpo con Chromium headless usando la
                                  sesión de X de Zen (cookies read-only).
  web                          -> {needs_webfetch: true} (el modelo usa WebFetch)

Salida JSON (con texto fuente):
  {source, url, title, author, date, duration_min, description, chapters,
   method, transcript_path, chars}
  (description = texto del autor con sus links/recursos; en X es el texto
   del tweet; chapters = [{min, title}] si el video los tiene)
Salida JSON (web):
  {source, url, needs_webfetch: true}
Salida error: {source, url, error}
"""
import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import urllib.request

YT = ("youtube.com", "youtu.be")
TT = ("tiktok.com",)
IG = ("instagram.com",)
TW = ("twitter.com", "x.com")
WHISPER_MODEL = "mlx-community/whisper-large-v3-turbo"
SUB_LANGS = "es,es-ES,es-419,es-orig,en,en-US,en-orig"
WHISPER_CANDIDATES = (
    "mlx_whisper",
    os.path.expanduser("~/.local/pipx/venvs/mlx-whisper/bin/mlx_whisper"),
)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
ZEN_PROFILES = os.path.expanduser("~/Library/Application Support/zen/Profiles")


LEARNING_DIR = os.path.expanduser("~/Code/_vault/_personal/learning")


def dedup_key(url, source):
    """Clave estable por fuente — los params de tracking (?si=, ?s=) varían
    entre shares del mismo contenido, así que se deduplica por el ID."""
    pats = {
        "youtube": r"(?:v=|youtu\.be/|/live/|/shorts/)([\w-]{8,})",
        "twitter": r"/status/(\d+)",
        "instagram": r"/(?:reel|p)/([\w-]{5,})",
        "tiktok": r"/video/(\d+)",
    }
    pat = pats.get(source)
    if pat:
        m = re.search(pat, url)
        if m:
            return m.group(1)
    return url.split("?")[0]


def find_existing_note(url, source):
    """Ruta de la nota existente que ya referencia este contenido, o None."""
    key = dedup_key(url, source)
    if not key or len(key) < 5 or not os.path.isdir(LEARNING_DIR):
        return None
    p = run(["grep", "-rl", "--include=*.md", "-F", key, LEARNING_DIR])
    hits = [h for h in (p.stdout or "").strip().splitlines() if h]
    return hits[0] if hits else None


def detect_source(url):
    u = url.lower()
    if any(d in u for d in YT):
        return "youtube"
    if any(d in u for d in TT):
        return "tiktok"
    if any(d in u for d in IG):
        return "instagram"
    if any(d in u for d in TW):
        return "twitter"
    return "web"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def whisper_bin():
    for c in WHISPER_CANDIDATES:
        found = shutil.which(c) or (c if os.path.isfile(c) else None)
        if found:
            return found
    return None


def ytdlp_meta(url):
    """Metadata completa vía JSON dump: un call, parseo robusto, incluye
    description (links/recursos del autor) y chapters (timestamps)."""
    p = run(["yt-dlp", "--skip-download", "--no-playlist", "--no-warnings", "-j", url])
    if p.returncode != 0:
        return None, (p.stderr.strip().splitlines() or ["yt-dlp no pudo leer el link"])[-1]
    try:
        info = json.loads(p.stdout.strip().splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        return None, "yt-dlp devolvió metadata ilegible"
    upload_date = info.get("upload_date") or ""
    date = None
    if re.fullmatch(r"\d{8}", upload_date):
        date = f"{upload_date[:4]}-{upload_date[4:6]}-{upload_date[6:]}"
    duration = info.get("duration")
    dur_min = round(duration / 60) if isinstance(duration, (int, float)) else None
    desc = (info.get("description") or "").strip()
    chapters = [{"min": round((c.get("start_time") or 0) / 60, 1),
                 "title": c.get("title")}
                for c in (info.get("chapters") or [])]
    return {"title": info.get("title"),
            "author": info.get("uploader") or info.get("channel"),
            "date": date, "duration_min": dur_min,
            "description": desc[:4000] or None,
            "chapters": chapters or None}, None


def fetch_subs(url, base):
    """Baja subtítulos (manuales o auto) y devuelve el .srt preferido (es > en)."""
    run(["yt-dlp", "--skip-download", "--write-auto-subs", "--write-subs",
         "--sub-langs", SUB_LANGS, "--convert-subs", "srt", "--no-warnings",
         "-o", base, url])
    found = glob.glob(base + "*.srt")
    if not found:
        return None

    def rank(f):
        fl = f.lower()
        if re.search(r"\.es[.\-]", fl) or fl.endswith(".es.srt"):
            return 0
        if re.search(r"\.en[.\-]", fl) or fl.endswith(".en.srt"):
            return 1
        return 2

    found.sort(key=rank)
    return found[0]


def clean_srt(path):
    """SRT -> texto plano. Quita índices/timestamps/tags y dedup de auto-subs."""
    text = open(path, encoding="utf-8", errors="ignore").read()
    out, prev = [], None
    for ln in text.splitlines():
        s = ln.strip()
        if not s or s.isdigit() or "-->" in s:
            continue
        s = re.sub(r"<[^>]+>", "", s)          # tags inline de auto-subs
        s = re.sub(r"\s+", " ", s).strip()
        if s and s != prev:                    # auto-subs repiten líneas
            out.append(s)
            prev = s
    return "\n".join(out)


def fetch_audio_whisper(url, base, tmp):
    """Camino principal para video: baja audio y transcribe con mlx_whisper."""
    wb = whisper_bin()
    if not wb:
        return None
    run(["yt-dlp", "-x", "--audio-format", "mp3", "--no-warnings",
         "-o", base + ".%(ext)s", url])
    audios = glob.glob(base + ".mp3")
    if not audios:
        return None
    run([wb, audios[0], "--model", WHISPER_MODEL,
         "-f", "txt", "-o", tmp, "--output-name", "whisper"])
    txts = glob.glob(os.path.join(tmp, "whisper*.txt"))
    if not txts:
        return None
    return open(txts[0], encoding="utf-8", errors="ignore").read().strip()


# ---------------------------------------------------------------- twitter/x

def tweet_id_from(url):
    m = re.search(r"/status/(\d+)", url)
    return m.group(1) if m else None


def syndication_token(tid):
    """Token del endpoint público de syndication — replica el algoritmo de
    react-tweet: ((id/1e15)*π) en base 36, sin ceros ni punto."""
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    num = (int(tid) / 1e15) * 3.141592653589793
    i, frac = int(num), num - int(num)
    s = ""
    while i:
        s = digits[i % 36] + s
        i //= 36
    f = ""
    for _ in range(12):
        frac *= 36
        f += digits[int(frac)]
        frac -= int(frac)
    return (s + "." + f).replace("0", "").replace(".", "")


def fetch_tweet(tid):
    """Tweet completo vía cdn.syndication.twimg.com. None si no existe,
    está protegido, o el endpoint cambió."""
    u = (f"https://cdn.syndication.twimg.com/tweet-result"
         f"?id={tid}&token={syndication_token(tid)}&lang=en")
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.loads(r.read().decode())
    except Exception:
        return None
    return d if isinstance(d, dict) and d.get("user") else None


def zen_x_cookies():
    """Cookies de x.com de la sesión de Zen, en formato Playwright. Busca en
    todos los perfiles el que tenga auth_token. Read-only (copia el DB para no
    tocar el lock de Zen). None si no hay sesión."""
    if not os.path.isdir(ZEN_PROFILES):
        return None
    same = {0: "None", 1: "Lax", 2: "Strict"}
    for prof in sorted(glob.glob(os.path.join(ZEN_PROFILES, "*", "cookies.sqlite"))):
        tmp = tempfile.mktemp(suffix=".sqlite")
        try:
            shutil.copy(prof, tmp)
            con = sqlite3.connect(tmp)
            rows = con.execute(
                "SELECT name,value,host,path,expiry,isSecure,isHttpOnly,sameSite "
                "FROM moz_cookies WHERE host LIKE '%x.com' OR host LIKE '%twitter.com'"
            ).fetchall()
            con.close()
        except Exception:
            continue
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)
        if not any(r[0] == "auth_token" for r in rows):
            continue
        cookies = []
        for n, v, h, pth, exp, sec, http, ss in rows:
            e = int(exp / 1000) if exp and exp > 1e12 else (int(exp) if exp and exp > 0 else -1)
            cookies.append({"name": n, "value": v, "domain": h, "path": pth or "/",
                            "expires": e, "secure": bool(sec), "httpOnly": bool(http),
                            "sameSite": same.get(ss, "Lax")})
        return cookies
    return None


# ruido de UI de X que no es parte del artículo
_X_UI_NOISE = re.compile(
    r"^(To view keyboard shortcuts.*|View keyboard shortcuts|Follow|Following|"
    r"Reply|Repost|Quote|Bookmark|Share|Show more|Show this thread|"
    r"·|\d+(\.\d+)?[KMB]?|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec.*)$")


def render_x_article(article_url):
    """Renderiza el cuerpo de un X Article con Chromium headless + la sesión de
    Zen. Devuelve (texto, None) o (None, motivo). Import de playwright lazy:
    solo se paga cuando hay un artículo."""
    cookies = zen_x_cookies()
    if not cookies:
        return None, "sin sesión de X en Zen (no encontré auth_token)"
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return None, "playwright no instalado"
    ua = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")
    try:
        with sync_playwright() as p:
            b = p.chromium.launch(headless=True)
            ctx = b.new_context(user_agent=ua)
            ctx.add_cookies(cookies)
            pg = ctx.new_page()
            # el contenido del artículo vive en el body; el <article> lo envuelve
            # de forma inconsistente entre renders, así que esperamos y leemos body
            wait_body = "() => document.body && document.body.innerText.length > 900"
            get_body = ("() => { const a = document.querySelector('article'); "
                        "const t = a && a.innerText ? a.innerText : ''; "
                        "return t.length > 900 ? t : document.body.innerText; }")
            raw = ""
            # el cold start de X a veces sirve una página incompleta; 2 intentos
            for attempt in range(2):
                if attempt == 0:
                    pg.goto(article_url, wait_until="domcontentloaded", timeout=30000)
                else:
                    pg.reload(wait_until="domcontentloaded", timeout=30000)
                try:
                    pg.wait_for_function(wait_body, timeout=25000)
                except Exception:
                    pg.wait_for_timeout(4000)
                raw = pg.evaluate(get_body)
                if len(raw) > 900:
                    break
            b.close()
    except Exception as e:
        return None, f"render falló: {str(e)[:120]}"
    lines, seen = [], False
    for ln in (raw or "").splitlines():
        s = ln.strip()
        if not s or _X_UI_NOISE.match(s):
            continue
        # descartar el header del tweet hasta el primer párrafo largo real
        if not seen and len(s) < 40:
            continue
        seen = True
        lines.append(s)
    text = "\n".join(lines)
    if len(text) < 200:
        return None, "el artículo renderizó vacío o demasiado corto"
    return text, None


def tweet_to_text(d):
    """Texto fuente a partir del JSON del tweet: texto + links expandidos +
    tweet citado + cuerpo de X Article si aplica."""
    parts = [d.get("text") or ""]
    urls = [u.get("expanded_url") for u in (d.get("entities") or {}).get("urls", [])
            if u.get("expanded_url")]
    if urls:
        parts.append("Links del tweet:\n" + "\n".join(f"- {u}" for u in urls))
    q = d.get("quoted_tweet")
    if q:
        qu = (q.get("user") or {}).get("screen_name", "?")
        parts.append(f"--- Tweet citado (@{qu}) ---\n{q.get('text') or ''}")
    if d.get("article"):
        art_url = next((u for u in urls if "/i/article/" in u), None)
        body, err = render_x_article(art_url) if art_url else (None, "sin URL de artículo")
        if body:
            parts.append(f"--- Cuerpo del X Article ---\n{body}")
        else:
            parts.append(f"[NOTA: este post enlaza un X Article que no se pudo "
                         f"renderizar ({err}). Si se necesita el cuerpo completo, "
                         f"pedir el texto pegado.]")
    photos = d.get("photos") or []
    if photos:
        parts.append(f"[El tweet incluye {len(photos)} imagen(es) — no extraídas.]")
    return "\n\n".join(p for p in parts if p)


def emit(obj, code=0):
    print(json.dumps(obj, ensure_ascii=False, indent=2))
    sys.exit(code)


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        emit({"error": "uso: fetch.py <url>"}, 1)
    url = sys.argv[1].strip()
    source = detect_source(url)

    existing = find_existing_note(url, source)
    if existing:
        emit({"source": source, "url": url, "duplicate": True,
              "existing_note": existing,
              "note": "ya existe una nota de este contenido — no reproceses; "
                      "reportá la ruta existente"})

    tmp = tempfile.mkdtemp(prefix="learn-")
    base = os.path.join(tmp, "src")

    # Web -> lo extrae el modelo con WebFetch (artículo, doc, blog).
    if source == "web":
        emit({"source": source, "url": url, "needs_webfetch": True})

    # twitter/x: texto y metadata vía syndication; si no hay video, acá termina
    tweet_text = None
    if source == "twitter":
        tid = tweet_id_from(url)
        tweet = fetch_tweet(tid) if tid else None
        if tweet:
            tweet_text = tweet_to_text(tweet)
            user = tweet.get("user") or {}
            if "video" not in tweet:
                tpath = os.path.join(tmp, "content.txt")
                open(tpath, "w", encoding="utf-8").write(tweet_text)
                emit({"title": " ".join((tweet.get("text") or "").split())[:90] or None,
                      "author": user.get("name") or user.get("screen_name"),
                      "date": (tweet.get("created_at") or "")[:10] or None,
                      "duration_min": None,
                      "source": source, "url": url, "method": "syndication",
                      "transcript_path": tpath, "chars": len(tweet_text)})
            # tweet con video: sigue al camino yt-dlp+whisper; el texto se combina al final

    # video/audio: youtube, tiktok, instagram, twitter-con-video
    meta, err = ytdlp_meta(url)
    if meta is None:
        if source == "twitter":
            emit({"source": source, "url": url,
                  "error": "tweet no accesible: borrado, protegido o endpoint de "
                           "X caído. Pegá el texto del tweet como modo paste."}, 1)
        emit({"source": source, "url": url, "error": err}, 1)

    # whisper primero, siempre: la transcripción local es la fuente de calidad;
    # los subtítulos automáticos quedan solo como red de emergencia
    transcript, method = fetch_audio_whisper(url, base, tmp), "whisper"
    if not transcript:
        sub = fetch_subs(url, base)
        if sub:
            transcript, method = clean_srt(sub), "subtitles-fallback"
    if not transcript:
        extra = "" if whisper_bin() else " (mlx_whisper no disponible)"
        emit({**meta, "source": source, "url": url,
              "error": "sin audio transcribible ni subtítulos" + extra}, 1)

    if tweet_text:
        transcript = (f"[Texto del tweet]\n{tweet_text}\n\n"
                      f"[Transcripción del video]\n{transcript}")

    tpath = os.path.join(tmp, "transcript.txt")
    open(tpath, "w", encoding="utf-8").write(transcript)

    # cleanup: el mp3 (~100-200MB en videos largos) y los srt ya cumplieron;
    # solo el transcript queda para el agente
    for leftover in glob.glob(base + "*") + glob.glob(os.path.join(tmp, "whisper*.txt")):
        try:
            os.remove(leftover)
        except OSError:
            pass

    emit({**meta, "source": source, "url": url, "method": method,
          "transcript_path": tpath, "chars": len(transcript)})


if __name__ == "__main__":
    main()
