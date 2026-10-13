#!/usr/bin/env python3
"""Migrate only the recognized inline Bash block, preserving other local content."""
from pathlib import Path
import shutil
import subprocess
import os
import tempfile

LEGACY = '''alias syu="sudo dnf upgrade"

# Modern developer aliases
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -la --icons --group-directories-first"
    alias tree="eza --tree --icons"
fi

if command -v bat >/dev/null 2>&1; then
    alias cat="bat --paging=never"
fi

if command -v duf >/dev/null 2>&1; then
    alias df="duf"
fi

# Zoxide smart jumping (replaces cd)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# FZF keybindings & fuzzy completion
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"

eval "$(starship init bash)"
fastfetch
'''
DIRECTORY_LOADER = '''if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi'''
HOOK = '''# Dotfiles portable developer configuration
if [ -r "$HOME/.bashrc.d/dotfiles.sh" ]; then
    . "$HOME/.bashrc.d/dotfiles.sh"
fi
'''


def migrate(path: Path) -> None:
    """Back up and migrate an exact known block; never remove edited local code.

    Args:
        path: Local Bash startup file.
    Raises:
        ValueError: The startup file is a symlink requiring manual integration.
        OSError: Backup or update fails.
    """
    if path.is_symlink():
        raise ValueError('Symlinked .bashrc: integrate shell/dotfiles.sh manually')
    original = path.read_text() if path.exists() else ''
    updated = original.replace(LEGACY, '')
    # shortcut: loader detection matches raw text; manually source the fragment when a loader is unreachable.
    if DIRECTORY_LOADER not in updated and HOOK not in updated:
        updated = updated.rstrip('\n') + '\n\n' + HOOK
    if updated == original:
        return
    if path.exists():
        with tempfile.NamedTemporaryFile(prefix=path.name + '.backup-', dir=path.parent, delete=False) as backup:
            shutil.copy2(path, backup.name)
            print(f'Bash backup: {backup.name}')
    mode = path.stat().st_mode & 0o7777 if path.exists() else 0o600
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', prefix=path.name + '.tmp-',
                                         dir=path.parent, delete=False) as temporary:
            temporary_name = temporary.name
            temporary.write(updated)
            temporary.flush()
            os.fchmod(temporary.fileno(), mode)
            os.fsync(temporary.fileno())
        os.replace(temporary_name, path)
    finally:
        if temporary_name is not None:
            Path(temporary_name).unlink(missing_ok=True)


def migrate_git(path: Path, include: Path) -> None:
    """Prepend a portable include and remove only matching legacy Git values.

    Local identity and differing overrides stay after the include and take priority.
    Raises ValueError for symlinked files and OSError or CalledProcessError on failure.
    """
    if path.is_symlink():
        raise ValueError('Symlinked .gitconfig: integrate git/developer.gitconfig manually')
    original = path.read_text() if path.exists() else ''
    settings = {
        'core.pager': 'delta', 'interactive.diffFilter': 'delta --color-only',
        'delta.navigate': 'true', 'delta.light': 'false', 'delta.side-by-side': 'false',
        'delta.line-numbers': 'true', 'delta.syntax-theme': 'Catppuccin Mocha',
    }
    with tempfile.TemporaryDirectory(dir=path.parent) as directory:
        draft = Path(directory) / 'gitconfig'
        draft.write_text(original)
        for key, value in settings.items():
            result = subprocess.run(['git', 'config', '--file', str(draft), '--fixed-value',
                                     '--unset-all', key, value], capture_output=True, text=True, check=False)
            if result.returncode not in (0, 5):
                raise RuntimeError(f'Cannot migrate Git setting {key}: {result.stderr}')
        # Let Git quote the path instead of implementing its configuration grammar.
        prefix = Path(directory) / 'include'
        subprocess.run(['git', 'config', '--file', str(prefix), '--add', 'include.path', str(include)], check=True)
        existing = subprocess.run(['git', 'config', '--file', str(draft), '--get-all', 'include.path'],
                                  capture_output=True, text=True, check=False)
        if existing.returncode not in (0, 1):
            raise RuntimeError('Cannot read Git include settings')
        updated = draft.read_text()
        if str(include) not in existing.stdout.splitlines():
            updated = prefix.read_text() + updated
        if updated == original:
            return
        if path.exists():
            with tempfile.NamedTemporaryFile(prefix=path.name + '.backup-', dir=path.parent, delete=False) as backup:
                shutil.copy2(path, backup.name)
                print(f'Git backup: {backup.name}')
            draft.chmod(path.stat().st_mode & 0o777)
        else:
            draft.chmod(0o600)
        draft.write_text(updated)
        os.replace(draft, path)


if __name__ == '__main__':
    home = Path.home()
    migrate(home / '.bashrc')
    migrate_git(home / '.gitconfig', home / '.config/git/developer.gitconfig')
