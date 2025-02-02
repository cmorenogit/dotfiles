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

# Define la función lazynvm para cargar NVM
lazynvm() {
  unset -f nvm node npm npx pnpm yarn
  export NVM_DIR="$HOME/.nvm"
  [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh" # Carga nvm
  [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" # Carga bash_completion
}

# Función genérica para comandos que dependen de NVM
nvm_command() {
  lazynvm
  command="$1"
  shift
  $command "$@"
}

# Alias para los comandos de NVM
pnpm() { nvm_command pnpm "$@"; }
yarn() { nvm_command yarn "$@"; }
nvm() { nvm_command nvm "$@"; }
node() { nvm_command node "$@"; }
npm() { nvm_command npm "$@"; }
npx() { nvm_command npx "$@"; }
