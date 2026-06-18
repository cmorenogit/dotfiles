#!/usr/bin/env bash
# pi-eval.sh — segunda opinión de un modelo de OTRO linaje (gpt-5.5 vía pi/OAuth ChatGPT).
#
# Encapsula la invocación NO-INTERACTIVA de `pi` como evaluador externo cross-model,
# con todos los gotchas ya resueltos (ver SKILL.md). Imprime SOLO la respuesta del
# modelo en stdout; los errores van a stderr.
#
# Uso:
#   pi-eval.sh "<prompt de evaluacion>"
#   echo "<prompt>" | pi-eval.sh
#
# Variables de entorno:
#   PI_EVAL_TIMEOUT  segundos antes de abortar cada intento (default 120)
#   PI_EVAL_RAW=1    NO anteponer la "regla de oro" anti-razonamiento (avanzado)
#
# Exit codes:
#   0  respuesta obtenida (en stdout)
#   1  sin respuesta tras 2 intentos (timeout/cuelgue) — ver stderr
#   2  `pi` no está en PATH
#
# REGLA DE ORO (verificada empíricamente, 2026-06-17): gpt-5.5-codex razona
# proporcional a cuánto lo invita el prompt. Sin una instrucción explícita de
# "juicio inmediato, sin razonar paso a paso" + formato de salida acotado, una
# evaluación cuelga >120s. Con ella, responde en 5-41s. Por eso este helper
# antepone esa instrucción por defecto.

set -uo pipefail

TIMEOUT="${PI_EVAL_TIMEOUT:-120}"

# --- leer prompt de $1 o de stdin --------------------------------------------
if [ "$#" -ge 1 ] && [ -n "${1:-}" ]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

if [ -z "${PROMPT//[[:space:]]/}" ]; then
  echo "pi-eval: prompt vacío" >&2
  exit 1
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "pi-eval: 'pi' CLI no encontrado en PATH" >&2
  exit 2
fi

# --- regla de oro: forzar juicio inmediato, no razonamiento extendido --------
if [ "${PI_EVAL_RAW:-0}" != "1" ]; then
  PROMPT="Responde de inmediato con tu juicio. NO razones paso a paso ni expliques tu proceso. Sé conciso y directo.

${PROMPT}"
fi

OUT="$(mktemp -t pi-eval.XXXXXX)"
trap 'rm -f "$OUT"' EXIT

_run() {
  # PI_OFFLINE / PI_SKIP_VERSION_CHECK: evitan el chequeo de versión por red que
  #   cuelga intermitentemente al arrancar (NO bloquean la llamada al LLM).
  # sin --provider / --model: usa el default del usuario (openai-codex / gpt-5.5
  #   por OAuth de ChatGPT). Pasar --provider openai o --model EXIGE una API key
  #   inexistente y FALLA — no tocar.
  # >| sobrescribe aunque zsh tenga noclobber.
  PI_OFFLINE=1 PI_SKIP_VERSION_CHECK=1 timeout "$TIMEOUT" \
    pi -p --no-tools --no-session -nc -ne -ns --thinking off --mode json "$1" \
    >| "$OUT" 2>/dev/null
}

_parse() {
  # El stream JSON está buffereado (stdout no-TTY no hace flush por línea): el
  # archivo queda vacío hasta que el proceso termina. Tomamos el ÚLTIMO
  # message_end del assistant; no nos fiamos de los bytes para saber si funcionó.
  python3 - "$OUT" <<'PY'
import json, sys
last = None
try:
    fh = open(sys.argv[1])
except OSError:
    sys.exit(0)
for line in fh:
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except Exception:
        continue
    if ev.get("type") == "message_end" and ev.get("message", {}).get("role") == "assistant":
        last = ev["message"]
def text(m):
    c = (m or {}).get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "\n".join(p.get("text", "") for p in c if isinstance(p, dict))
    return ""
sys.stdout.write(text(last).strip())
PY
}

# Intento 1 + 1 reintento (cubre cold-start / cuelgue transitorio de red).
_run "$PROMPT"; REPLY="$(_parse)"
if [ -z "$REPLY" ]; then
  _run "$PROMPT"; REPLY="$(_parse)"
fi

if [ -z "$REPLY" ]; then
  echo "pi-eval: sin respuesta tras 2 intentos (timeout=${TIMEOUT}s)." >&2
  echo "pi-eval: si el prompt invita a razonar, acortá el input y forzá un formato de salida breve (veredicto + N líneas)." >&2
  exit 1
fi

printf '%s\n' "$REPLY"
