"""Verify exact legacy migration and precedence of local Git overrides."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('migration', Path(__file__).resolve().parents[1] / 'scripts/migrate-shell.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)

class MigrationTests(unittest.TestCase):
    """Protect local startup files and Git override precedence during migration."""
    def test_bash_replace_failure_preserves_original_and_cleans_temporary(self) -> None:
        """A failed replacement must preserve startup content and its mode."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.bashrc'
            original = 'export LOCAL=yes\n' + migration.LEGACY
            path.write_text(original)
            path.chmod(0o640)
            with patch.object(migration.os, 'replace', side_effect=OSError('simulated replacement failure')):
                with self.assertRaises(OSError):
                    migration.migrate(path)
            self.assertEqual(path.read_text(), original)
            self.assertEqual(path.stat().st_mode & 0o7777, 0o640)
            backups = list(Path(directory).glob('.bashrc.backup-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), original)
            self.assertEqual(list(Path(directory).glob('.bashrc.tmp-*')), [])

    def test_bash_replacement_preserves_mode(self) -> None:
        """Atomic migration retains the original permissions."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.bashrc'
            path.write_text(migration.LEGACY)
            path.chmod(0o640)
            migration.migrate(path)
            self.assertEqual(path.stat().st_mode & 0o7777, 0o640)
            self.assertEqual(list(Path(directory).glob('.bashrc.tmp-*')), [])

    def test_exact_bash_block_migrates_once(self) -> None:
        """Remove the recognized block once and preserve unrelated settings."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.bashrc'
            path.write_text('export LOCAL=yes\n' + migration.LEGACY)
            migration.migrate(path)
            migration.migrate(path)
            self.assertIn('export LOCAL=yes', path.read_text())
            self.assertNotIn('starship init', path.read_text())
            self.assertEqual(path.read_text().count(migration.HOOK), 1)
            self.assertEqual(len(list(Path(directory).glob('.bashrc.backup-*'))), 1)

    def test_git_local_override_wins_and_identity_survives(self) -> None:
        """Portable Git defaults must not override local identity or preferences."""
        with tempfile.TemporaryDirectory(prefix='git home ') as directory:
            path = Path(directory) / '.gitconfig'
            fragment = Path(directory) / 'developer.gitconfig'
            fragment.write_text('[core]\n pager=delta\n[delta]\n light=false\n')
            path.write_text('[user]\n name=Local User\n[core]\n pager=less\n[delta]\n light=false\n')
            migration.migrate_git(path, fragment)
            migration.migrate_git(path, fragment)
            def value(key: str) -> str:
                """Read one effective test-config value with includes enabled."""
                return subprocess.check_output(['git', 'config', '--file', str(path), '--includes', '--get', key], text=True).strip()
            self.assertEqual(value('core.pager'), 'less')
            self.assertEqual(value('user.name'), 'Local User')
            self.assertEqual(value('delta.light'), 'false')
            self.assertEqual(len(list(Path(directory).glob('.gitconfig.backup-*'))), 1)

if __name__ == '__main__':
    unittest.main()
