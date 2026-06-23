#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# beat-pair.sh — Crea el worktree-par (back ↔ app) al crear un worktree Beat,
# escribe el CLAUDE.local.md en ambos, y dispara la preparación (beat-prep) en el
# back. Reemplaza el hook inline 'pair-beat' del config.toml para NO volcar su
# código en la terminal (wt muestra solo la línea que lo invoca).
#
# Se llama desde ~/.config/worktrunk/config.toml → [pre-start] pair-beat.
# Args (sustituidos por wt antes de invocar):
#   $1 = worktree_path   $2 = branch   $3 = branch | sanitize
# ─────────────────────────────────────────────────────────────────────────────
set +e

WT_PATH="$1"
BRANCH="$2"
BRANCH_SAN="$3"

# Gate: solo actúa en los repos Beat (apprecio-pulse / ryr). Otros → no-op.
remote=$(git -C "$WT_PATH" config --get remote.origin.url 2>/dev/null || echo "")
case "$remote" in
  *apprecio-pulse*)
    paired=$HOME/Code/work/rr-project/app-rr-cesar
    paired_label="app-rr-cesar (app colaborador)"
    this_label="back-pulse-cesar (backoffice)"
    ;;
  *ryr-app*|*ryr-39255*)
    paired=$HOME/Code/work/rr-project/back-pulse-cesar
    paired_label="back-pulse-cesar (backoffice)"
    this_label="app-rr-cesar (app colaborador)"
    ;;
  *) exit 0 ;;
esac

# Path absoluto de info/exclude (soluciona paths relativos en worktrees nuevos).
resolve_exclude() {
  local wt="$1" common_dir
  common_dir=$(cd "$wt" && cd "$(git rev-parse --git-common-dir)" && pwd)
  echo "$common_dir/info/exclude"
}

# Ignorar CLAUDE.local.md localmente (idempotente, no se commitea).
this_exclude=$(resolve_exclude "$WT_PATH")
grep -qxF "CLAUDE.local.md" "$this_exclude" 2>/dev/null || echo "CLAUDE.local.md" >> "$this_exclude"

existing=""
if [ -d "$paired" ]; then
  paired_exclude=$(resolve_exclude "$paired")
  grep -qxF "CLAUDE.local.md" "$paired_exclude" 2>/dev/null || echo "CLAUDE.local.md" >> "$paired_exclude"

  paired_worktree_path="$paired.$BRANCH_SAN"
  existing=$(git -C "$paired" worktree list | awk -v b="[$BRANCH]" '$NF == b {print $1; exit}')
  if [ -z "$existing" ]; then
    echo "[beat-pair] Creando pair en $paired_worktree_path para rama $BRANCH..."
    if git -C "$paired" show-ref --verify --quiet "refs/heads/$BRANCH"; then
      git -C "$paired" worktree add "$paired_worktree_path" "$BRANCH" 2>&1 | sed 's/^/[beat-pair] /'
    else
      git -C "$paired" worktree add -b "$BRANCH" "$paired_worktree_path" 2>&1 | sed 's/^/[beat-pair] /'
    fi
    existing=$(git -C "$paired" worktree list | awk -v b="[$BRANCH]" '$NF == b {print $1; exit}')
  fi
fi

write_local() {
  local here="$1" there="$2" here_lbl="$3" there_lbl="$4" pair_block
  if [ -n "$there" ]; then
    pair_block="- Path: $there"
  else
    pair_block="- No existe pair para rama $BRANCH en $there_lbl.
- Para crear: cd <ruta-base-del-pair> && wt switch --create $BRANCH"
  fi
  cat > "$here/CLAUDE.local.md" <<EOF
# Beat Workspace (auto-generado por wt — no commitear)

## Worktree actual
- Repo: $here_lbl
- Rama: $BRANCH
- Path: $here

## Pair
- Repo: $there_lbl
$pair_block

## Reglas de edición
- Para editar código del pair, usa EXACTAMENTE el path del pair arriba.
- Nunca edites en la carpeta raíz del repo pair — puede estar en otra rama.
- Si \`git branch --show-current\` no coincide con \`$BRANCH\`, avisa al usuario antes de seguir.
- Ambos repos (backoffice y app colaborador) se editan con Claude Code.
  No hay restricción a Lovable; el README del repo app es info de origen, no regla.

## Engram — política Beat
- Proyecto: SIEMPRE usa \`project: "recognition-and-rewards"\` en mem_save / mem_search / mem_context.
- No dejes que Engram infiera del cwd — fragmenta memoria entre worktrees.
- Contenido PE personal (carrera, evaluaciones, 1:1): usa \`scope: "personal"\`, NO project Beat.
- No uses ~/.claude/projects/*/memory/ para contenido cross-worktree — fragmenta igual. Prefiere Engram.
EOF
}

write_local "$WT_PATH" "${existing:-}" "$this_label" "$paired_label"
[ -n "${existing:-}" ] && write_local "$existing" "$WT_PATH" "$paired_label" "$this_label"
echo "[beat-pair] CLAUDE.local.md escrito en worktree(s) Beat."

# Tras crear el par: preparar el back (secrets + aislado + deps) con reporte VISIBLE.
case "$remote" in
  *apprecio-pulse*) ( cd "$WT_PATH" && bash "$HOME/.config/worktrunk/scripts/beat-prep.sh" ) ;;
esac
