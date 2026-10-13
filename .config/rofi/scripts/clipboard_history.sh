#!/usr/bin/env bash
# Copy, delete, or confirm clearing clipboard history without changing it on cancel.
set -euo pipefail
trap 'notify-send "Clipboard" "Clipboard operation failed." >&2 || true' ERR
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT

while true; do
    history=$(cliphist list)
    [[ -n $history ]] || { notify-send 'Clipboard' 'History is empty.'; exit 0; }
    mapfile -t entries <<< "$history"
    status=0
    selected=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i -no-custom -format i \
        -kb-remove-char-forward Control+d -kb-remove-word-forward Control+Alt+d \
        -kb-custom-1 Delete -kb-custom-2 Control+Delete \
        -p 'CLIPBOARD HISTORY' -mesg '[ ENTER ] COPY   [ DEL ] DELETE ENTRY   [ CTRL+DEL ] CLEAR ALL' \
        -theme "$HOME/.config/rofi/themes/clipboard.rasi") || status=$?
    [[ $status != 1 ]] || exit 0
    case $status in
        0|10)
            [[ $selected =~ ^(0|[1-9][0-9]*)$ ]] && (( selected < ${#entries[@]} )) || exit 1
            if [[ $status == 10 ]]; then
                printf '%s\n' "${entries[selected]}" | cliphist delete
                continue
            fi
            # Decode first: a failed lookup must not replace the current clipboard.
            printf '%s\n' "${entries[selected]}" | cliphist decode > "$payload"
            wl-copy < "$payload"
            notify-send 'Clipboard' 'Content copied!' -t 2000
            exit 0
            ;;
        11)
            confirm_status=0
            confirmation=$(printf 'Cancel\nClear all\n' | rofi -dmenu -no-custom -format i \
                -p 'Clear clipboard history?' -theme "$HOME/.config/rofi/themes/current.rasi") || confirm_status=$?
            if [[ $confirm_status == 0 && $confirmation == 1 ]]; then cliphist wipe; fi
            [[ $confirm_status == 0 || $confirm_status == 1 ]] || exit 1
            ;;
        *) exit "$status" ;;
    esac
done
