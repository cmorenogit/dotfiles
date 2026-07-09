#!/usr/bin/env bash
# inbox-add.sh — encola URLs en la cola de captura del learning system.
#
# Uso:   inbox-add.sh "texto con una o más URLs y nota opcional"
#        printf '%s' "texto" | inbox-add.sh
#
# Extrae las URLs del texto, deduplica contra el inbox, appendea cada una con
# fecha y la nota (el texto restante), y hace commit + push del vault.
# Determinístico a propósito: lo corre Hermes desde Telegram sin criterio de LLM.
set -uo pipefail

VAULT="$HOME/Code/_vault"
REL="_personal/learning/inbox.md"
INBOX="$VAULT/$REL"

TEXT="${*:-}"
if [ -z "$TEXT" ] && [ ! -t 0 ]; then
  TEXT="$(cat)"
fi
if [ -z "$TEXT" ]; then
  echo "uso: inbox-add.sh <texto con URLs> (o por stdin)"
  exit 1
fi
if [ ! -f "$INBOX" ]; then
  echo "no existe $INBOX"
  exit 1
fi

cd "$VAULT" || exit 1
git pull --rebase --autostash --quiet 2>/dev/null

URLS=$(printf '%s\n' "$TEXT" \
  | grep -Eo 'https?://[^[:space:]<>"]+' \
  | sed -E 's/[),.;!?]+$//' \
  | awk '!seen[$0]++')
if [ -z "$URLS" ]; then
  echo "no encontré URLs en el mensaje"
  exit 1
fi

# Nota = el texto sin las URLs, colapsado (máx 120 chars)
NOTE=$(printf '%s\n' "$TEXT" \
  | sed -E 's~https?://[^[:space:]<>"]+~~g' \
  | tr '\n' ' ' \
  | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//' \
  | cut -c1-120)

STAMP=$(date '+%Y-%m-%d %H:%M')
ADDED=0
DUPES=0
while IFS= read -r url; do
  [ -z "$url" ] && continue
  if grep -qF "$url" "$INBOX"; then
    DUPES=$((DUPES + 1))
    continue
  fi
  line="- [ ] $url — $STAMP"
  [ -n "$NOTE" ] && line="$line — $NOTE"
  printf '%s\n' "$line" >> "$INBOX"
  ADDED=$((ADDED + 1))
done <<< "$URLS"

if [ "$ADDED" -eq 0 ]; then
  echo "0 nuevas · $DUPES ya estaban en la cola"
  exit 0
fi

git add "$REL"
git commit --quiet -m "docs(learning): inbox +$ADDED link(s)" -- "$REL"
if git push --quiet 2>/dev/null; then
  SYNC="pusheado"
else
  # reintento único: pudo entrar un commit remoto entre el pull y el push
  git pull --rebase --autostash --quiet 2>/dev/null && git push --quiet 2>/dev/null \
    && SYNC="pusheado" || SYNC="commit local, push falló (¿offline?)"
fi

PEND=$(grep -c '^- \[ \]' "$INBOX")
MSG="✅ $ADDED link(s) en cola"
[ "$DUPES" -gt 0 ] && MSG="$MSG · $DUPES duplicado(s) omitido(s)"
echo "$MSG · pendientes: $PEND · $SYNC"
