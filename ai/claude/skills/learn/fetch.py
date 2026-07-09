#!/usr/bin/env python3
"""fetch.py — extractor determinista de /learn.

Dado un URL: detecta la fuente, extrae metadata y la transcripción FUENTE.
Imprime JSON a stdout. La parte interpretativa (destilar, criticar, vincular)
la hace el modelo en SKILL.md; este script solo hace lo mecánico y reproducible.

Fuentes:
  youtube / tiktok  -> yt-dlp subtítulos (es/en) -> fallback audio + mlx_whisper
  twitter / web     -> {needs_webfetch: true}  (el modelo usa WebFetch)

Salida JSON (video con transcripción):
  {source, url, title, author, date, duration_min, method, transcript_path, chars}
Salida JSON (texto):
  {source, url, needs_webfetch: true}
"""
import sys, os, json, re, subprocess, tempfile, glob

YT = ("youtube.com", "youtu.be")
TT = ("tiktok.com",)
TW = ("twitter.com", "x.com")
WHISPER_MODEL = "mlx-community/whisper-large-v3-turbo"
SUB_LANGS = "es,es-ES,es-419,es-orig,en,en-US,en-orig"


def detect_source(url):
    u = url.lower()
    if any(d in u for d in YT):
        return "youtube"
    if any(d in u for d in TT):
        return "tiktok"
    if any(d in u for d in TW):
        return "twitter"
    return "web"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def ytdlp_meta(url):
    """Metadata liviana via --print (sin descargar el JSON completo)."""
    fmt = "%(title)s\n%(uploader)s\n%(upload_date)s\n%(duration)s\n%(id)s"
    p = run(["yt-dlp", "--skip-download", "--no-warnings", "--print", fmt, url])
    if p.returncode != 0:
        return None, (p.stderr.strip() or "yt-dlp no pudo leer el link")
    parts = (p.stdout.strip().split("\n") + ["", "", "", "", ""])[:5]
    title, uploader, upload_date, duration, vid = parts
    date = None
    if re.fullmatch(r"\d{8}", upload_date or ""):
        date = f"{upload_date[:4]}-{upload_date[4:6]}-{upload_date[6:]}"
    dur_min = None
    try:
        if duration not in ("", "NA"):
            dur_min = round(int(float(duration)) / 60)
    except ValueError:
        pass
    return {"title": title or None, "author": uploader or None,
            "date": date, "duration_min": dur_min, "id": vid or None}, None


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
    """Fallback: baja audio y transcribe localmente con mlx_whisper."""
    run(["yt-dlp", "-x", "--audio-format", "mp3", "--no-warnings",
         "-o", base + ".%(ext)s", url])
    audios = glob.glob(base + ".mp3")
    if not audios:
        return None
    run(["mlx_whisper", audios[0], "--model", WHISPER_MODEL,
         "-f", "txt", "-o", tmp, "--output-name", "whisper"])
    txts = glob.glob(os.path.join(tmp, "whisper*.txt"))
    if not txts:
        return None
    return open(txts[0], encoding="utf-8", errors="ignore").read().strip()


def emit(obj, code=0):
    print(json.dumps(obj, ensure_ascii=False, indent=2))
    sys.exit(code)


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        emit({"error": "uso: fetch.py <url>"}, 1)
    url = sys.argv[1].strip()
    source = detect_source(url)

    # Texto -> lo extrae el modelo con WebFetch (hilo de X completo / artículo).
    if source in ("twitter", "web"):
        emit({"source": source, "url": url, "needs_webfetch": True})

    # Video/audio -> yt-dlp + whisper.
    meta, err = ytdlp_meta(url)
    if meta is None:
        emit({"source": source, "url": url, "error": err}, 1)

    tmp = tempfile.mkdtemp(prefix="learn-")
    base = os.path.join(tmp, "src")
    transcript, method = None, None

    sub = fetch_subs(url, base)
    if sub:
        transcript, method = clean_srt(sub), "subtitles"
    if not transcript:
        transcript, method = fetch_audio_whisper(url, base, tmp), "whisper"
    if not transcript:
        emit({**meta, "source": source, "url": url,
              "error": "sin subtítulos ni audio transcribible"}, 1)

    tpath = os.path.join(tmp, "transcript.txt")
    open(tpath, "w", encoding="utf-8").write(transcript)
    emit({**meta, "source": source, "url": url, "method": method,
          "transcript_path": tpath, "chars": len(transcript)})


if __name__ == "__main__":
    main()
