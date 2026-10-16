-- Shared application commands; requiring this module does not launch anything.
return {
    terminal = "kitty",
    fileManager = "dolphin",
    menu = "rofi -show drun",
    wifi = "~/.config/rofi/scripts/wifi.sh",
    bluetooth = "~/.config/rofi/scripts/bluetooth.sh",
    wallpaper = "~/.config/rofi/scripts/wallpaper.sh",
}
