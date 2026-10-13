#!/usr/bin/env bash
# Link tracked configs and portable fragments, preserving local settings in backups.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v python3 >/dev/null
command -v git >/dev/null

# Preserve conflicts, including dangling links, before installing one source.
link_item() {
    local source=$1 target=$2 backup
    mkdir -p "$(dirname "$target")"
    if [[ -L $target && $(readlink -f "$target") == "$source" ]]; then
        echo "Already linked: $target"
        return
    fi
    if [[ -e $target || -L $target ]]; then
        backup=$(mktemp -d "${target}.backup-XXXXXX")
        mv -- "$target" "$backup/original"
        echo "Backup: $backup/original"
    fi
    ln -s -- "$source" "$target"
    echo "Linked: $target"
}

# Migrate before linking so unsupported shell ownership fails without changing configs.
python3 "$DOTFILES_DIR/scripts/migrate-shell.py"
for item in "$DOTFILES_DIR/.config/"*; do
    link_item "$item" "$HOME/.config/$(basename "$item")"
done
link_item "$DOTFILES_DIR/shell/dotfiles.sh" "$HOME/.bashrc.d/dotfiles.sh"
link_item "$DOTFILES_DIR/git/developer.gitconfig" "$HOME/.config/git/developer.gitconfig"
echo 'Configuration installed. Open a new interactive shell to use the fragment.'
