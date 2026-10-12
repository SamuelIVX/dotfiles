#!/usr/bin/env bash

# Options with Nerd Font icons
lock="󰌾  Lock"
suspend="󰤄  Suspend"
logout="󰍃  Log Out"
reboot="󰜉  Reboot"
shutdown="󰐥  Shut Down"

# Confirmation / Prompt
options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | rofi -dmenu -p "Power" -theme-str '
window {
    width: 320px;
    border-radius: 12px;
}
listview {
    lines: 5;
    scrollbar: false;
}
')"

case "$chosen" in
    "$lock")
        hyprlock
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        hyprctl dispatch exit
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$shutdown")
        systemctl poweroff
        ;;
esac
