#!/usr/bin/env bash
set -euo pipefail

# Show clipboard history with custom message using dedicated theme
cliphist list | rofi -dmenu -i \
    -p "  CLIPBOARD HISTORY" \
    -mesg " [ ENTER ]  PASTE     [ DEL ]  DELETE ENTRY     [ CTRL+DEL ]  CLEAR ALL" \
    -theme ~/.config/rofi/themes/clipboard.rasi | cliphist decode | wl-copy

# Notify if copied
if [ -n "$(wl-paste 2>/dev/null || true)" ]; then
    notify-send "Clipboard" "Content copied!" -t 2000
fi
