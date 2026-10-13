#!/usr/bin/env bash
# Apply only the backed-up, verified developer file-watch setting.
set -euo pipefail
if (( EUID != 0 )); then
    echo 'Run: sudo ./scripts/apply-system-optimizations.sh' >&2
    exit 1
fi
python3 "$(dirname "${BASH_SOURCE[0]}")/inotify.py"
echo 'File-watch setting verified. Other system settings were not changed.'
