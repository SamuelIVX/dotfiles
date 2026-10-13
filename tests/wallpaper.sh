#!/usr/bin/env bash
# Regression checks for wallpaper refresh and listener ownership.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
export HOME="$task_tmp/home" XDG_RUNTIME_DIR="$task_tmp/runtime" HYPRLAND_INSTANCE_SIGNATURE=test
export TEST_LOG="$task_tmp/images"
mkdir -p "$HOME/Pictures/Wallpapers" "$XDG_RUNTIME_DIR/hypr/test" "$task_tmp/bin"
touch "$HOME/Pictures/Wallpapers/csm_wallpaper.jpg"
python3 - "$XDG_RUNTIME_DIR/hypr/test/.socket2.sock" <<'PY'
import os, socket, sys
try:
    s = socket.socket(socket.AF_UNIX)
    s.bind(sys.argv[1])
except PermissionError:
    # Restricted runners forbid socket creation; socat is mocked regardless.
    os.symlink('/run/dbus/system_bus_socket', sys.argv[1])
PY
cat > "$task_tmp/bin/hyprctl" <<'MOCK'
#!/bin/bash
printf '{"id":%s}\n' "${TEST_WORKSPACE:-1}"
MOCK
cat > "$task_tmp/bin/awww" <<'MOCK'
#!/bin/bash
if [[ $1 == query ]]; then exit "${TEST_DAEMON_STATUS:-0}"; fi
printf '%s\n' "$2" >> "$TEST_LOG"
MOCK
cat > "$task_tmp/bin/socat" <<'MOCK'
#!/bin/bash
sleep 0.5
printf 'activewindow>>ignored\nworkspace>>1\n'
MOCK
chmod +x "$task_tmp/bin/"*
export PATH="$task_tmp/bin:$PATH"
script="$repo/.config/hypr/scripts/wallpaper.sh"
bash "$script" --once
[[ $(wc -l < "$TEST_LOG") == 1 ]]
TEST_WORKSPACE=6 bash "$script" --once
[[ $(wc -l < "$TEST_LOG") == 1 ]]
rm "$TEST_LOG"
bash "$script" &
listener=$!
for ((i=0; i<100; i++)); do [[ -f $TEST_LOG ]] && break; sleep 0.01; done
bash "$script"
wait "$listener"
[[ $(wc -l < "$TEST_LOG") == 2 ]]
rm "$HOME/Pictures/Wallpapers/csm_wallpaper.jpg"
if bash "$script" --once >/dev/null 2>&1; then echo 'Missing image accepted' >&2; exit 1; fi
if bash "$script" --invalid >/dev/null 2>&1; then exit 1; fi
printf 'Wallpaper regression checks passed\n'
