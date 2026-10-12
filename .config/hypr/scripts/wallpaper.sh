#!/bin/bash

# Transition settings: clean bezier fade matching monitor refresh rate (144Hz)
TRANSITION_OPTS="--transition-type fade --transition-bezier .23,1,.32,1 --transition-duration 0.8 --transition-fps 144"

change_wallpaper(){
workspace=$(hyprctl activeworkspace -j | jq -r '.id')

# Set wallpapers for each workspace
case $workspace in
    1)
        awww img /home/samhb/Pictures/Wallpapers/csm_wallpaper.jpg $TRANSITION_OPTS
        ;;
    2)
        awww img /home/samhb/Pictures/Wallpapers/reze_wallpaper.png $TRANSITION_OPTS
        ;;
    3)
        awww img /home/samhb/Pictures/Wallpapers/dandadan_wallpaper.png $TRANSITION_OPTS
        ;;
    4)
        awww img /home/samhb/Pictures/Wallpapers/goku_black_wallpaper.jpg $TRANSITION_OPTS
        ;;
    5)
        awww img /home/samhb/Pictures/Wallpapers/evangelion_wallpaper.png $TRANSITION_OPTS
        ;;
esac

}

# Set initial wallpaper
change_wallpaper

# Socket Path:
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Listen for workspace events
socat -U - UNIX-CONNECT:${SOCKET_PATH} | while read -r line; do
    if echo "$line" | grep -q "workspace>>"; then
        change_wallpaper
    fi
done
