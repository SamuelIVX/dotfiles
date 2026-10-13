#!/usr/bin/env bash
# Select an intact SSID and delegate credentials to NetworkManager in Kitty.
set -euo pipefail
trap 'notify-send "Wi-Fi" "Could not open the network connection prompt." >&2 || true' ERR
networks=$(nmcli --escape no --get-values SSID device wifi list)
declare -A seen=()
ssids=()
# shortcut: SSIDs containing newlines are not representable in this menu; use nmcli directly for those.
while IFS= read -r ssid; do
    [[ -n $ssid ]] || continue
    if [[ ! ${seen["$ssid"]+present} ]]; then ssids+=("$ssid"); seen["$ssid"]=1; fi
done <<< "$networks"
(( ${#ssids[@]} )) || { notify-send 'Wi-Fi' 'No named networks found.'; exit 0; }
status=0
selected=$(printf '%s\n' "${ssids[@]}" | rofi -dmenu -i -no-custom -format i \
    -theme "$HOME/.config/rofi/themes/current.rasi" -p 'Wi-Fi Networks') || status=$?
[[ $status != 1 ]] || exit 0
[[ $status == 0 ]] || exit "$status"
[[ $selected =~ ^(0|[1-9][0-9]*)$ ]] && (( selected < ${#ssids[@]} )) || exit 1
# No password is collected or placed in command arguments by this script.
kitty --hold -e nmcli --ask device wifi connect "${ssids[selected]}"
