#!/usr/bin/env bash
# Select wallpaper paths by index, preserving punctuation and duplicate basenames.
set -euo pipefail
trap 'notify-send "Wallpaper" "Could not select or apply wallpaper." >&2 || true' ERR
wallpaper_dir="$HOME/Pictures/Wallpapers"
[[ -d $wallpaper_dir ]] || wallpaper_dir="$HOME/Pictures/Wallpaper"
[[ -d $wallpaper_dir ]] || { notify-send 'Wallpaper' 'Wallpaper directory not found.'; exit 1; }
# A temporary null-delimited list preserves paths and lets discovery failures surface.
list=$(mktemp)
trap 'rm -f "$list"' EXIT
find "$wallpaper_dir" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) -print0 | sort -z > "$list"
mapfile -d '' -t wallpapers < "$list"
(( ${#wallpapers[@]} )) || { notify-send 'Wallpaper' 'No wallpapers found.'; exit 0; }
names=()
for wallpaper in "${wallpapers[@]}"; do
    name=${wallpaper#"$wallpaper_dir/"}
    # Display control characters safely; the index still resolves the original path.
    printf -v name '%q' "$name"
    names+=("$name")
done
status=0
selected=$(printf '%s\n' "${names[@]}" | rofi -dmenu -i -no-custom -format i \
    -theme "$HOME/.config/rofi/themes/current.rasi" -p 'Select Wallpaper' \
    -theme-str 'window {width: 600px;} listview {lines: 10;}') || status=$?
[[ $status != 1 ]] || exit 0
[[ $status == 0 ]] || exit "$status"
[[ $selected =~ ^(0|[1-9][0-9]*)$ ]] && (( selected < ${#wallpapers[@]} )) || exit 1
awww img "${wallpapers[selected]}" --transition-type fade --transition-bezier .23,1,.32,1 \
    --transition-duration 0.8 --transition-fps 144
notify-send 'Wallpaper Changed' "${names[selected]}" -i "${wallpapers[selected]}" -t 3000
