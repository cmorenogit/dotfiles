function cdd() {
	cd "$(ls -d -- */ | fzf)" || echo "Invalid directory"
}

function j() {
	fname=$(declare -f -F _z)

	[ -n "$fname" ] || source "$DOTLY_PATH/modules/z/z.sh"

	_z "$1"
}

function recent_dirs() {
	# This script depends on pushd. It works better with autopush enabled in ZSH
	escaped_home=$(echo $HOME | sed 's/\//\\\//g')
	selected=$(dirs -p | sort -u | fzf)

	cd "$(echo "$selected" | sed "s/\~/$escaped_home/")" || echo "Invalid directory"
}

eg() {
  eza --color=always | grep --color=always "$@"
}


ssh() {
    # Color diferente para sesiones SSH (ejemplo: tinte azul oscuro)
    printf '\e]11;#1a1a2e\a'

    command ssh "$@"

    # Restaurar color original al salir
    printf '\e]111\a'  # OSC 111 resetea al color por defecto
}

# Lazygit - change directory on exit
# bd init wrapper: auto-commit off, backup off by default
bd-init() {
    bd init "$@" || return 1
    bd config set dolt.auto-commit off
    # Overwrite config.yaml with explicit backup off (default enables it when git remote exists)
    cat >| .beads/config.yaml <<'YAML'
auto-start-daemon: true
backup:
  enabled: false
  git-push: false

dolt.auto-commit: "off"
YAML
}

# Lazygit - change directory on exit
lg() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir
    lazygit "$@"
    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
        cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
        rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}

# ──────────────────────────────────────────────────────────────────────────
# Supabase worktree stacks (sb-*) — identify & stop local Supabase instances
# Each back worktree runs an isolated Supabase stack; its containers carry the
# label com.supabase.cli.project = <project_id> (ending in -wt<slot>). These map
# a running container back to its worktree dir and stop it without cd-ing in.
# ──────────────────────────────────────────────────────────────────────────
SB_WORKTREE_ROOT="${SB_WORKTREE_ROOT:-$HOME/Code/work/rr-project}"

# Running Supabase project_ids (unique, blanks removed)
_sb_running_projects() {
    docker ps --format '{{.Label "com.supabase.cli.project"}}' 2>/dev/null \
        | grep -v '^$' | sort -u
}

# Worktree dir(s) that declare a given project_id in supabase/config.toml
_sb_dirs_for_project() {
    grep -rl "project_id = \"$1\"" "$SB_WORKTREE_ROOT"/*/supabase/config.toml 2>/dev/null \
        | sed 's#/supabase/config.toml##'
}

# sb-who — show each running Supabase stack and the worktree it belongs to
sb-who() {
    local found=0 pid st dirs n
    while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        found=1
        st=$(docker ps --filter "label=com.supabase.cli.project=$pid" \
                    --filter "name=supabase_db_" --format '{{.Status}}' | head -1)
        dirs=$(_sb_dirs_for_project "$pid")
        n=$(printf '%s\n' "$dirs" | grep -c .)
        printf '\n● %s  (%s)\n' "$pid" "${st:-running}"
        if [ "$n" -eq 0 ]; then
            printf '    ⚠ ningún worktree declara este project_id (¿stack huérfano?)\n'
        elif [ "$n" -gt 1 ]; then
            printf '    ⚠ %s carpetas comparten este slot — no se puede desambiguar:\n' "$n"
            printf '%s\n' "$dirs" | sed 's#.*/#      - #'
        else
            printf '    %s\n' "$(basename "$dirs")"
        fi
    done <<< "$(_sb_running_projects)"
    if [ "$found" -eq 0 ]; then
        echo "No hay stacks Supabase corriendo."
        return 0
    fi
    printf '\n  ── comandos ─────────────────────────────────────\n'
    printf '  sb-stop <slot|all>   parar un stack       (ej: sb-stop wt4)\n'
    printf '  sb-stop-others       parar todos menos el worktree actual\n'
    printf '  sb-who               este listado\n'
}

# sb-stop <slot|project_id|all> — stop a Supabase stack without cd
sb-stop() {
    local arg="$1"
    if [ -z "$arg" ]; then
        echo "uso: sb-stop <slot|project_id|all>   (ej: sb-stop wt4 · sb-stop all)"
        echo "corriendo ahora:"; _sb_running_projects | sed 's/^/  /'
        return 1
    fi
    if [ "$arg" = "all" ]; then
        supabase stop --all; return $?
    fi
    local pat="-${arg}\$|^${arg}\$" match
    match=$(_sb_running_projects | grep -E -- "$pat" | head -1)
    local pid="${match:-$arg}"
    echo "→ supabase stop --project-id $pid"
    supabase stop --project-id "$pid"
}

# sb-stop-others — stop every running stack EXCEPT the current worktree's
sb-stop-others() {
    local root cur pid
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$root" ] || [ ! -f "$root/supabase/config.toml" ]; then
        echo "No estoy en un proyecto Supabase (sin supabase/config.toml)."; return 1
    fi
    cur=$(grep -E '^[[:space:]]*project_id' "$root/supabase/config.toml" \
            | head -1 | sed -E 's/.*"(.*)".*/\1/')
    echo "Worktree actual: $cur — se mantiene, paro el resto."
    while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        if [ "$pid" = "$cur" ]; then
            echo "  ✓ $pid (actual)"
        else
            echo "  ✗ $pid → stop"
            supabase stop --project-id "$pid" >/dev/null 2>&1
        fi
    done <<< "$(_sb_running_projects)"
}

# pair — saltar al worktree par de Beat (back <-> app), preservando subdirectorio
function pair() {
    local dest
    case "$PWD" in
        */back-pulse-cesar*) dest="${PWD/back-pulse-cesar/app-rr-cesar}" ;;
        */app-rr-cesar*)     dest="${PWD/app-rr-cesar/back-pulse-cesar}" ;;
        *) echo "pair: no estás en un worktree Beat (back/app)"; return 1 ;;
    esac
    if [ -d "$dest" ]; then
        cd "$dest"
    else
        echo "pair: no existe el par -> $dest"; return 1
    fi
}
