#!/usr/bin/env bash
# Portable interactive developer aliases, navigation, completion, and prompt.
[[ $- == *i* ]] || return 0
alias syu='sudo dnf upgrade'
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
    alias tree='eza --tree --icons'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
command -v duf >/dev/null 2>&1 && alias df=duf
if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init bash)"; fi
if command -v fzf >/dev/null 2>&1; then eval "$(fzf --bash)"; fi
if command -v starship >/dev/null 2>&1; then eval "$(starship init bash)"; fi
if command -v fastfetch >/dev/null 2>&1; then fastfetch; fi
