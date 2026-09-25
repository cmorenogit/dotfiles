#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-promote.sh — Promueve el trunk de una feature a main con TODO lo que el preview necesita,
# y verifica que el preview quedó sirviendo el código correcto.
#
# Por qué: el preview de Beat depende de 3 labels puestos JUNTOS en el PR del back hacia main
# (deploy:staging corre backend-tests — sin él se omiten errores, RYR-287 —, deploy:preview
# despliega, skip:e2e evita los e2e por capacidad, temporal). Faltó alguno en RYR-287/298/299,
# ponerlos de a uno cancela runs, quitar deploy:preview DESTRUYE el preview, la app se empareja
# por nombre de rama, y un símbolo retirado por el PR que main todavía usa tiró el preview 29 h.
#
# Uso (desde el worktree del BACK, en la rama del trunk, todo commiteado y pusheado):
#   beat-promote.sh --title "<título>" --body <archivo> [--app-body <archivo>]   crear/actualizar
#   beat-promote.sh … --dry-run      corre todos los chequeos y muestra qué haría, sin tocar GitHub
#   beat-promote.sh --check <PR>                                                  verificar preview
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

BACK_REPO="ivaldovinos-app/apprecio-pulse"
APP_REPO="ivaldovinos-app/ryr-39255"
LABELS=(deploy:staging deploy:preview skip:e2e)
SCRIPTS="$HOME/.config/worktrunk/scripts"

TITLE="" BODY="" APP_BODY="" CHECK="" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --app-body) APP_BODY="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "Uso: beat-promote.sh --title <t> --body <archivo> [--app-body <archivo>] | --check <PR>"; exit 2 ;;
  esac
done

fail=0
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
bad()  { echo "  ✗ $*"; fail=1; }

# ── --check <PR>: ¿el preview sirve lo que tiene que servir? ────────────────────
if [ -n "$CHECK" ]; then
  echo "[beat-promote] check del PR #$CHECK"
  info="$(gh pr view "$CHECK" -R "$BACK_REPO" --json baseRefName,headRefName,headRefOid,labels,state 2>/dev/null)" \
    || { echo "  ✗ no pude leer el PR #$CHECK"; exit 2; }
  base="$(echo "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["baseRefName"])')"
  head="$(echo "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["headRefName"])')"
  sha="$(echo "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["headRefOid"])')"
  have="$(echo "$info" | python3 -c 'import json,sys;print(" ".join(l["name"] for l in json.load(sys.stdin)["labels"]))')"
  [ "$base" = "main" ] && ok "base = main" || bad "base = $base: el preview solo se despliega con base main"
  for l in "${LABELS[@]}"; do
    case " $have " in *" $l "*) ok "label $l" ;; *) bad "falta el label $l (agregá los 3 juntos: gh pr edit $CHECK -R $BACK_REPO --add-label $(IFS=,; echo "${LABELS[*]}"))" ;; esac
  done
  if git rev-parse --verify -q HEAD >/dev/null 2>&1 && [ "$(git branch --show-current)" = "$head" ]; then
    [ "$(git rev-parse HEAD)" = "$sha" ] && ok "HEAD local = HEAD del PR (${sha:0:9})" || warn "HEAD local ($(git rev-parse --short HEAD)) ≠ PR (${sha:0:9}): ¿falta push?"
  fi
  checks="$(gh pr checks "$CHECK" -R "$BACK_REPO" 2>/dev/null)"; rc=$?
  case $rc in
    0) ok "CI: todos los checks en verde" ;;
    8) warn "CI: hay checks pendientes (esperá con Monitor; no afirmes que el preview está listo)" ;;
    *) bad "CI: hay checks en rojo"; echo "$checks" | grep -iE "fail|error" | head -5 | sed 's/^/      /' ;;
  esac
  comment="$(gh pr view "$CHECK" -R "$BACK_REPO" --json comments -q '[.comments[] | select(.body | test("Preview Environment"; "i"))] | last | .body' 2>/dev/null)"
  if [ -n "$comment" ]; then
    # El preview despliega refs/pull/N/merge: el "Commit:" del comentario es ese merge commit.
    # Sirve el HEAD si uno de sus padres es el HEAD del PR.
    dep="$(echo "$comment" | sed -nE 's/.*Commit: `([0-9a-f]{7,40})`.*/\1/p' | head -1)"
    if [ -n "$dep" ]; then
      parents="$(gh api "repos/$BACK_REPO/commits/$dep" -q '[.parents[].sha] | join(" ")' 2>/dev/null)"
      case " $parents $dep" in
        *"$sha"*) ok "el preview sirve el HEAD del PR (${sha:0:9}; merge commit $dep)" ;;
        *) bad "el preview sirve $dep, que NO contiene el HEAD ${sha:0:9}: está viejo (re-correr preview-deploy)" ;;
      esac
    else
      warn "el comentario de preview no trae 'Commit:'; no pude verificar qué sirve"
    fi
    appline="$(echo "$comment" | grep -i "Rama app" | head -1)"
    case "$appline" in
      *"misma que el PR"*) ok "app emparejada: $(echo "$appline" | sed -E 's/.*`([^`]+)`.*/\1/')" ;;
      "") warn "el comentario no informa la rama de la app" ;;
      *) bad "la app NO usa la rama del PR: $appline" ;;
    esac
    echo "$comment" | grep -oE 'https://[a-z0-9.-]+pages\.dev' | sort -u | sed 's/^/      URL: /'
  else
    warn "todavía no hay comentario 'Preview Environment' en el PR"
  fi
  run="$(gh run list -R "$BACK_REPO" --branch "$head" --workflow preview-deploy.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)"
  if [ -n "$run" ] && gh run view "$run" -R "$BACK_REPO" --log 2>/dev/null | grep -q "App branch '.*' not found"; then
    bad "el preview usó la app de main: no existe la rama '$head' en $APP_REPO (el par se empareja por nombre)"
  fi
  if command -v python3 >/dev/null && [ -f "$HOME/.claude/skills/preview-db/preview_db.py" ]; then
    if gcloud auth print-access-token >/dev/null 2>&1; then
      python3 "$HOME/.claude/skills/preview-db/preview_db.py" list 2>/dev/null | grep -q "pr-$CHECK " \
        && ok "Cloud Run tiene el tag pr-$CHECK vivo" || warn "Cloud Run todavía no tiene el tag pr-$CHECK"
    else
      warn "gcloud sin sesión: no pude verificar Cloud Run (César: ! gcloud auth login)"
    fi
  fi
  exit "$fail"
fi

# ── crear / actualizar el PR de promoción ───────────────────────────────────────
[ -f scripts/adlc/gate-check.sh ] || { echo "ERROR: corré desde la raíz del worktree del BACK"; exit 2; }
branch="$(git branch --show-current)"
[ "$branch" != "main" ] || { echo "ERROR: estás en main; corré desde la rama del trunk"; exit 2; }
[ -n "$BODY" ] && [ -f "$BODY" ] || { echo "ERROR: falta --body <archivo> (el body del PR, con 'Spec: docs/specs/…' y '## Promotion PR' si consolida subPRs)"; exit 2; }
[ -n "$TITLE" ] || { echo "ERROR: falta --title"; exit 2; }

echo "[beat-promote] $branch → main"
git fetch -q origin main "$branch" 2>/dev/null

# 1) Todo commiteado y pusheado
[ -z "$(git status --porcelain --untracked-files=no)" ] && ok "árbol limpio" || bad "hay cambios sin commitear"
ahead="$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo "?")"
[ "$ahead" = "0" ] && ok "pusheado" || bad "hay $ahead commits sin pushear (o la rama no existe en origin)"

# 2) SubPRs: ninguno abierto contra el trunk
open_sub="$(gh pr list -R "$BACK_REPO" --base "$branch" --state open --json number,title -q '.[] | "#\(.number) \(.title)"' 2>/dev/null)"
[ -z "$open_sub" ] && ok "no quedan subPRs abiertos contra $branch" || { bad "subPRs abiertos contra el trunk (mergealos o cerralos antes de promover):"; echo "$open_sub" | sed 's/^/      /'; }

# 3) Trunk al día con main
git merge-base --is-ancestor origin/main HEAD && ok "el trunk contiene origin/main" \
  || bad "el trunk no contiene origin/main: beat-isolate.sh --release-config → git merge origin/main → --refresh-config"

# 4) Migraciones en orden
if bash "$SCRIPTS/beat-migration-order.sh" >/tmp/beat-promote-mig.$$ 2>&1; then ok "migraciones en orden"
else bad "migraciones fuera de orden:"; grep "✗" /tmp/beat-promote-mig.$$ | sed 's/^/    /'; fi
rm -f /tmp/beat-promote-mig.$$

# 5) Par de la app (el preview la empareja por nombre de rama)
pair="$(dirname "$PWD")/app-rr-cesar.$(basename "$PWD" | sed 's/^back-pulse-cesar\.//')"
if [ -d "$pair" ]; then
  git -C "$pair" fetch -q origin main "$branch" 2>/dev/null
  if git -C "$pair" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
    [ -z "$(git -C "$pair" status --porcelain --untracked-files=no)" ] && ok "app: árbol limpio" || bad "app: cambios sin commitear en $pair"
    pa="$(git -C "$pair" rev-list --count "origin/$branch..HEAD" 2>/dev/null)"
    [ "$pa" = "0" ] && ok "app: rama '$branch' pusheada en $APP_REPO" || bad "app: $pa commits sin pushear"
  elif [ "$(git -C "$pair" rev-list --count origin/main..HEAD 2>/dev/null)" = "0" ]; then
    warn "app: sin cambios propios; el preview usará la app de main (correcto si la feature no toca la app)"
  else
    bad "app: la rama '$branch' tiene commits pero no está en $APP_REPO → git -C $pair push -u origin $branch"
  fi
else
  warn "no encontré el par de la app en $pair"
fi

# 6) Símbolos retirados que main todavía usa (merge-tree liviano, back)
changed="$(git diff --name-only origin/main...HEAD)"
removed="$(git diff origin/main...HEAD -- '*.ts' '*.tsx' | grep -E '^-\s*export\s+(async\s+)?(function|const|class|type|interface|enum)\s+' \
  | sed -E 's/^-\s*export\s+(async\s+)?(function|const|class|type|interface|enum)\s+([A-Za-z0-9_]+).*/\3/' | sort -u)"
added="$(git diff origin/main...HEAD -- '*.ts' '*.tsx' | grep -E '^\+\s*export\s+' | grep -oE '(function|const|class|type|interface|enum)\s+[A-Za-z0-9_]+' | awk '{print $2}' | sort -u)"
stale=0
for sym in $(comm -23 <(echo "$removed") <(echo "$added")); do
  users="$(git grep -lw "$sym" origin/main -- 'src' 'supabase/functions' 2>/dev/null | sed 's|^origin/main:||' | grep -vxF -f <(echo "$changed") | head -3)"
  if [ -n "$users" ]; then bad "el PR retira '$sym' y main lo usa en: $(echo $users)"; stale=1; fi
done
[ "$stale" = "0" ] && ok "ningún export retirado por el PR sigue en uso en main"

# 7) Gate igual a CI, con el body que se va a publicar
if bash "$SCRIPTS/beat-gate.sh" --body "$BODY" --base main >/tmp/beat-promote-gate.$$ 2>&1 && grep -q '"gate_passed": true' /tmp/beat-promote-gate.$$; then
  ok "gate local: PASSED"
else
  bad "gate local no pasó (detalle en la salida de beat-gate.sh --body $BODY --base main)"
fi
rm -f /tmp/beat-promote-gate.$$

if [ "$fail" -ne 0 ]; then echo "✗ [beat-promote] No se crea el PR: resolvé los ✗."; exit 1; fi

# 8) Crear o actualizar el PR con los 3 labels JUNTOS
if [ "$DRY" = "1" ]; then
  pr="$(gh pr list -R "$BACK_REPO" --head "$branch" --base main --state open --json number -q '.[0].number' 2>/dev/null)"
  if [ -n "$pr" ]; then echo "  [dry-run] gh pr edit $pr -R $BACK_REPO --add-label $(IFS=,; echo "${LABELS[*]}")"
  else echo "  [dry-run] gh pr create -R $BACK_REPO --base main --head $branch --title \"$TITLE\" --body-file $BODY $(printf -- '--label %s ' "${LABELS[@]}")"; fi
  echo "✓ [beat-promote] dry-run: todos los chequeos pasaron."; exit 0
fi
pr="$(gh pr list -R "$BACK_REPO" --head "$branch" --base main --state open --json number -q '.[0].number' 2>/dev/null)"
if [ -n "$pr" ]; then
  gh pr edit "$pr" -R "$BACK_REPO" --add-label "$(IFS=,; echo "${LABELS[*]}")" >/dev/null && ok "PR #$pr existente: labels agregados juntos"
else
  largs=(); for l in "${LABELS[@]}"; do largs+=(--label "$l"); done
  url="$(gh pr create -R "$BACK_REPO" --base main --head "$branch" --title "$TITLE" --body-file "$BODY" "${largs[@]}")" || { echo "✗ gh pr create falló"; exit 1; }
  pr="${url##*/}"; ok "PR creado: $url"
fi
if [ -n "$APP_BODY" ] && [ -d "$pair" ] && git -C "$pair" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
  apr="$(gh pr list -R "$APP_REPO" --head "$branch" --base main --state open --json number -q '.[0].number' 2>/dev/null)"
  [ -n "$apr" ] && ok "PR de la app existente: #$apr" \
    || { aurl="$(gh pr create -R "$APP_REPO" --base main --head "$branch" --title "$TITLE" --body-file "$APP_BODY")" && ok "PR de la app creado: $aurl"; }
fi

# 9) Verificación posterior
have="$(gh pr view "$pr" -R "$BACK_REPO" --json labels -q '[.labels[].name] | join(" ")')"
for l in "${LABELS[@]}"; do case " $have " in *" $l "*) ;; *) bad "después de crear, falta $l en #$pr" ;; esac; done
[ "$fail" -eq 0 ] && ok "los 3 labels están en #$pr"
echo "  Runs: gh run list -R $BACK_REPO --branch $branch --limit 5"
echo "  Cuando termine el pipeline: bash $SCRIPTS/beat-promote.sh --check $pr"
exit "$fail"
