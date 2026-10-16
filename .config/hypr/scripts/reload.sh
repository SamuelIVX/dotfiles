#!/usr/bin/env bash
# Reload the compositor and restart the bar/notifications through their launchers.
set -euo pipefail

# Validate the selected bar before restarting any desktop process.
[[ -x $HOME/.local/opt/waybar-lua/bin/waybar ]] || { echo 'Build Lua-capable Waybar first (docs/hyprland-lua.md).' >&2; exit 1; }

notify-send "Hyprland" "Reloading configuration..." || true

# Reload Hyprland
hyprctl reload

# Restart waybar
"$HOME/.config/waybar/scripts/launch.sh"

# Restart swaync
killall -9 swaync 2>/dev/null || true
nohup swaync </dev/null >/dev/null 2>&1 & disown

notify-send "Hyprland" "Reload complete!" -t 3000 || true
