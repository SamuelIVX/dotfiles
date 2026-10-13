#!/usr/bin/env bash
# Exercise picker selection, cancellation, and destructive clipboard actions.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
export HOME="$task_tmp/home" TEST_DIR="$task_tmp"
mkdir -p "$HOME/Pictures/Wallpapers/a" "$HOME/Pictures/Wallpapers/b" "$task_tmp/bin"
cat > "$task_tmp/bin/rofi" <<'MOCK'
#!/bin/bash
cat > "$TEST_DIR/menu"
count=0
[[ ! -f $TEST_DIR/count ]] || read -r count < "$TEST_DIR/count"
printf '%s\n' "$((count+1))" > "$TEST_DIR/count"
case ${TEST_ACTION:-copy}:$count in
    cancel:*|delete:1|wipe:2|reject:2) exit 1 ;;
    delete:0) printf '0\n'; exit 10 ;;
    wipe:0|reject:0) printf '0\n'; exit 11 ;;
    wipe:1) printf '1\n' ;;
    reject:1) printf '0\n' ;;
    *) printf '%s\n' "${TEST_INDEX:-0}" ;;
esac
MOCK
cat > "$task_tmp/bin/cliphist" <<'MOCK'
#!/bin/bash
case $1 in
    list) printf '1\tfirst\n2\tsecond\n' ;;
    decode) cat > "$TEST_DIR/entry"; [[ ${TEST_DECODE_FAIL:-0} == 0 ]] || exit 1; printf '\211PNG\000\377' ;;
    delete) cat > "$TEST_DIR/deleted" ;;
    wipe) touch "$TEST_DIR/wiped" ;;
esac
MOCK
cat > "$task_tmp/bin/wl-copy" <<'MOCK'
#!/bin/bash
cat > "$TEST_DIR/copied"
MOCK
cat > "$task_tmp/bin/nmcli" <<'MOCK'
#!/bin/bash
printf 'My Home WiFi\nGuest: Network\\name\nMy Home WiFi\n'
MOCK
cat > "$task_tmp/bin/kitty" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" > "$TEST_DIR/kitty"
MOCK
cat > "$task_tmp/bin/awww" <<'MOCK'
#!/bin/bash
printf '%s\n' "$2" > "$TEST_DIR/wallpaper"
MOCK
printf '#!/bin/bash\nexit 0\n' > "$task_tmp/bin/notify-send"
chmod +x "$task_tmp/bin/"*
export PATH="$task_tmp/bin:$PATH"
clipboard="$repo/.config/rofi/scripts/clipboard_history.sh"
TEST_ACTION=cancel bash "$clipboard"
[[ ! -f $TEST_DIR/copied ]]
rm "$TEST_DIR/count"
bash "$clipboard"
printf '\211PNG\000\377' > "$task_tmp/expected"
cmp "$task_tmp/expected" "$TEST_DIR/copied"
rm "$TEST_DIR/count" "$TEST_DIR/copied"
TEST_ACTION=delete bash "$clipboard"
[[ $(cat "$TEST_DIR/deleted") == $'1\tfirst' && ! -f $TEST_DIR/copied ]]
rm "$TEST_DIR/count"
TEST_ACTION=reject bash "$clipboard"
[[ ! -f $TEST_DIR/wiped ]]
rm "$TEST_DIR/count"
TEST_ACTION=wipe bash "$clipboard"
[[ -f $TEST_DIR/wiped ]]
rm "$TEST_DIR/count"
if TEST_DECODE_FAIL=1 bash "$clipboard" >/dev/null 2>&1; then exit 1; fi
[[ ! -f $TEST_DIR/copied ]]
rm "$TEST_DIR/count"
TEST_INDEX=1 bash "$repo/.config/rofi/scripts/wifi.sh"
[[ $(tail -n 1 "$TEST_DIR/kitty") == 'Guest: Network\name' ]]
[[ $(wc -l < "$TEST_DIR/menu") == 2 ]]
rm "$TEST_DIR/count" "$TEST_DIR/kitty"
TEST_ACTION=cancel bash "$repo/.config/rofi/scripts/wifi.sh"
[[ ! -f $TEST_DIR/kitty ]]
touch "$HOME/Pictures/Wallpapers/a/wallpaper[1].png" "$HOME/Pictures/Wallpapers/b/wallpaper[1].png"
rm "$TEST_DIR/count"
TEST_INDEX=1 bash "$repo/.config/rofi/scripts/wallpaper.sh"
[[ $(cat "$TEST_DIR/wallpaper") == "$HOME/Pictures/Wallpapers/b/wallpaper[1].png" ]]
printf 'Rofi regression checks passed\n'
