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
