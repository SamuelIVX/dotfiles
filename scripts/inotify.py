#!/usr/bin/env python3
"""Raise the workstation watch limit with preserved settings and rollback on failure."""
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

KEY = 'fs.inotify.max_user_watches'
MINIMUM = 524288


def apply(config: Path) -> int:
    """Preserve higher limits, update only KEY, and verify the running kernel.

    Args:
        config: Sysctl file to update; production uses the fixed workstation path.
    Returns:
        The verified effective watch limit.
    Raises:
        ValueError: Existing configuration is malformed.
        OSError: Configuration cannot be safely written.
        subprocess.CalledProcessError: A sysctl command fails.
        RuntimeError: The kernel does not report the requested value.
    """
    if config.is_symlink():
        raise ValueError('Refusing to replace a symlinked sysctl file')
    current = int(subprocess.check_output(['sysctl', '-n', KEY], text=True).strip())
    original = config.read_text() if config.exists() else ''
    lines = original.splitlines(keepends=True)
    pattern = re.compile(r'^\s*-?fs\.inotify\.max_user_watches\s*(?:=\s*|\s+)([^#;]+)')
    values = [int(match.group(1).strip()) for line in lines if (match := pattern.match(line))]
    desired = max(MINIMUM, current, *values)
    # Keep exact formatting when an existing single setting already suffices.
    if values == [desired]:
        updated = original
    else:
        updated = ''.join(line for line in lines if not pattern.match(line))
        if updated and not updated.endswith('\n'):
            updated += '\n'
        updated += f'{KEY}={desired}\n'
    backup = None
    changed = updated != original
    if changed:
        config.parent.mkdir(parents=True, exist_ok=True)
        metadata = config.stat() if config.exists() else None
        if metadata:
            fd, name = tempfile.mkstemp(prefix=config.name + '.backup-', dir=config.parent)
            os.close(fd)
            backup = Path(name)
            shutil.copy2(config, backup)
        fd, name = tempfile.mkstemp(prefix='.' + config.name, dir=config.parent)
        temporary = Path(name)
        try:
            with os.fdopen(fd, 'w') as output:
                os.fchmod(output.fileno(), stat.S_IMODE(metadata.st_mode) if metadata else 0o644)
                if metadata:
                    os.fchown(output.fileno(), metadata.st_uid, metadata.st_gid)
                output.write(updated)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, config)
        finally:
            temporary.unlink(missing_ok=True)
        if backup:
            print(f'Previous configuration saved to {backup}')
    try:
        if current != desired:
            subprocess.run(['sysctl', '-w', f'{KEY}={desired}'], check=True)
        effective = int(subprocess.check_output(['sysctl', '-n', KEY], text=True).strip())
        if effective != desired:
            raise RuntimeError(f'Expected {desired} watches, kernel reports {effective}')
    except (OSError, ValueError, subprocess.CalledProcessError, RuntimeError):
        if changed:
            if backup:
                os.replace(backup, config)
            else:
                config.unlink(missing_ok=True)
        try:
            subprocess.run(['sysctl', '-w', f'{KEY}={current}'], check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            print(f'Could not restore the previous kernel value: {error}', file=sys.stderr)
        raise
    return effective


if __name__ == '__main__':
    if os.geteuid() != 0:
        raise SystemExit('Run through sudo ./scripts/apply-system-optimizations.sh')
    print(f'Verified watch limit: {apply(Path("/etc/sysctl.d/99-workstation.conf"))}')
