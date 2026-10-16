#!/usr/bin/env bash
# Start or restart the verified user-local Waybar without falling back to legacy IPC.
set -euo pipefail
mode=${1:-restart}
if (( $# > 1 )) || [[ $mode != restart && $mode != --start ]]; then
    echo 'Usage: launch.sh [--start]' >&2
    exit 2
fi
waybar_binary="$HOME/.local/opt/waybar-lua/bin/waybar"
[[ -x $waybar_binary ]] || { echo "Missing Lua-capable Waybar: $waybar_binary (see docs/hyprland-lua.md)" >&2; exit 1; }
if [[ $mode == --start ]]; then
    exec "$waybar_binary"
fi
killall -9 waybar 2>/dev/null || true
nohup "$waybar_binary" </dev/null >/dev/null 2>&1 & disown
