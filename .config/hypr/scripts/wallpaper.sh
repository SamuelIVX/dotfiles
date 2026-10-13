#!/usr/bin/env bash
# Apply workspace wallpapers once or listen with one owner per Hyprland session.
set -euo pipefail

mode=${1:-listen}
if (( $# > 1 )) || [[ $mode != listen && $mode != --once ]]; then
    echo 'Usage: wallpaper.sh [--once]' >&2
    exit 2
fi
for command in hyprctl jq awww; do
    command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done

# Apply the current workspace image; unmapped workspaces retain the last image.
change_wallpaper() {
    local workspace image
    workspace=$(hyprctl activeworkspace -j | jq -er '.id')
    case "$workspace" in
        1) image=csm_wallpaper.jpg ;;
        2) image=reze_wallpaper.png ;;
        3) image=dandadan_wallpaper.png ;;
        4) image=goku_black_wallpaper.jpg ;;
        5) image=evangelion_wallpaper.png ;;
        *) return 0 ;;
    esac
    image="$HOME/Pictures/Wallpapers/$image"
    if [[ ! -f $image ]]; then
        echo "Wallpaper not found: $image" >&2
        return 1
    fi
    awww img "$image" --transition-type fade --transition-bezier .23,1,.32,1 \
        --transition-duration 0.8 --transition-fps 144
}

if [[ $mode == listen ]]; then
    : "${XDG_RUNTIME_DIR:?Missing XDG_RUNTIME_DIR}" "${HYPRLAND_INSTANCE_SIGNATURE:?Missing Hyprland session}"
    for command in socat flock; do
        command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
    done
    socket_path="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    [[ -S $socket_path ]] || { echo "Hyprland socket not found: $socket_path" >&2; exit 1; }
    exec 9>"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/wallpaper.lock"
    flock -n 9 || { echo 'Wallpaper listener already running.'; exit 0; }
fi

# Autostart order does not guarantee awww is ready; bound the wait to five seconds.
ready=false
for ((attempt=0; attempt<20; attempt++)); do
    if awww query >/dev/null 2>&1; then ready=true; break; fi
    sleep 0.25
done
[[ $ready == true ]] || { echo 'Wallpaper daemon unavailable after five seconds.' >&2; exit 1; }
change_wallpaper
[[ $mode == --once ]] && exit 0

socat -U - "UNIX-CONNECT:$socket_path" | while IFS= read -r line; do
    case "$line" in
        workspace\>\>*) change_wallpaper || echo 'Could not update workspace wallpaper.' >&2 ;;
    esac
done
