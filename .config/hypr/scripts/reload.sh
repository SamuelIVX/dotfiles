#!/bin/bash

notify-send "Hyprland" "Reloading configuration..."

# Reload Hyprland
hyprctl reload

# Restart waybar
killall -9 waybar 2>/dev/null || true
nohup waybar </dev/null >/dev/null 2>&1 & disown

# Restart swaync
killall -9 swaync 2>/dev/null || true
nohup swaync </dev/null >/dev/null 2>&1 & disown

notify-send "Hyprland" "Reload complete!" -t 3000
