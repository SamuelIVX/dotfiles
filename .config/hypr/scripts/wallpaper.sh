#!/bin/bash

# Get current workspace
change_wallpaper(){
workspace=$(hyprctl activeworkspace -j | jq -r '.id')

# Set wallpapers for each workspace
case $workspace in
    1)
        awww img /home/samhb/Pictures/Wallpapers/csm_wallpaper.jpg --transition-type=wave --transition-duration=1
        ;;
    2)
        awww img /home/samhb/Pictures/Wallpapers/reze_wallpaper.png --transition-type=any --transition-duration=1
        ;;
    3)
        awww img /home/samhb/Pictures/Wallpapers/dandadan_wallpaper.png --transition-type=grow --transition-duration=1
        ;;
    4)
        awww img /home/samhb/Pictures/Wallpapers/goku_black_wallpaper.jpg --transition-type=wipe --transition-duration=1
        ;;
    5)
        awww img --transition-type=outer --transition-pos 0.854,0.977 --transition-step 90 /home/samhb/Pictures/Wallpapers/evangelion_wallpaper.png
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
