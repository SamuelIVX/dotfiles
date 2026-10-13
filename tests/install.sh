#!/usr/bin/env bash
# Verify installation and migration preserve files, links, and local Git identity.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
export HOME="$task_tmp/home with spaces" GIT_CONFIG_GLOBAL="$task_tmp/home with spaces/.gitconfig" GIT_CONFIG_SYSTEM=/dev/null
mkdir -p "$HOME/.config" "$HOME/.bashrc.d"
ln -s "$task_tmp/missing" "$HOME/.config/kitty"
printf 'local bar\n' > "$HOME/.config/waybar"
printf 'local shell\n' > "$HOME/.bashrc.d/local.sh"
printf '[user]\n name = Local User\n' > "$HOME/.gitconfig"
cat > "$HOME/.bashrc" <<'RC'
# local setup
export CUSTOM_LOCAL=preserved
# Modern developer aliases
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
fi
# user code that must not be swallowed by partial migration
export KEEP_ME=yes
RC
# A partial or locally edited block must be preserved rather than guessed at.
bash "$repo/scripts/install-symlinks.sh" >/dev/null
[[ -L $HOME/.config/kitty && -L $HOME/.config/waybar ]]
[[ $(git config --global user.name) == 'Local User' ]]
[[ $(git config --global --get-all include.path | wc -l) == 1 ]]
[[ $(cat "$HOME/.bashrc.d/local.sh") == 'local shell' ]]
[[ $(cat "$HOME/.bashrc") == *'export KEEP_ME=yes'* ]]
[[ $(find "$HOME/.config" -maxdepth 1 -name 'kitty.backup-*' | wc -l) == 1 ]]
[[ $(find "$HOME/.config" -maxdepth 1 -name 'waybar.backup-*' | wc -l) == 1 ]]
bash "$repo/scripts/install-symlinks.sh" >/dev/null
[[ $(git config --global --get-all include.path | wc -l) == 1 ]]
[[ $(find "$HOME/.config" -maxdepth 1 -name 'waybar.backup-*' | wc -l) == 1 ]]
# Portable fragments must not initialize interactive tools in a script.
bash -c 'source "$HOME/.bashrc.d/dotfiles.sh"; [[ ! ${CUSTOM_LOCAL+present} ]]'
printf 'Installer regression checks passed\n'
