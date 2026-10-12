#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="$DOTFILES_DIR/.config"
TARGET_DIR="$HOME/.config"

echo "[+] Installing dotfiles symlinks into $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

for item in "$CONFIG_SOURCE"/*; do
    base="$(basename "$item")"
    target="$TARGET_DIR/$base"

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$item" ]; then
        echo "    [=] $base is already linked."
        continue
    fi

    if [ -e "$target" ]; then
        backup="${target}.backup-$(date +%s)"
        echo "    [!] Backing up existing $base to $backup"
        mv "$target" "$backup"
    fi

    ln -s "$item" "$target"
    echo "    [+] Linked $base -> $item"
done

echo "[✓] All dotfiles successfully linked!"
