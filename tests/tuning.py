"""Check sysctl preservation, verification, and rollback using disposable files."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('inotify', Path(__file__).resolve().parents[1] / 'scripts/inotify.py')
inotify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inotify)

class TuningTests(unittest.TestCase):
    def test_preserves_higher_limits_and_unrelated_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'workstation.conf'
            original = '# local comment\nvm.swappiness=80\nfs.inotify.max_user_watches=1048576\n'
            config.write_text(original)
            with patch.object(inotify.subprocess, 'check_output', side_effect=['524288', '1048576']), patch.object(inotify.subprocess, 'run') as run:
                self.assertEqual(inotify.apply(config), 1048576)
                self.assertEqual(config.read_text(), original)
                run.assert_called_once_with(['sysctl', '-w', 'fs.inotify.max_user_watches=1048576'], check=True)
                self.assertEqual(list(Path(directory).glob('*.backup-*')), [])

    def test_updates_once_and_backs_up(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'workstation.conf'
            original = '# custom\nvm.swappiness=80\nfs.inotify.max_user_watches = 8192\n'
            config.write_text(original)
            with patch.object(inotify.subprocess, 'check_output', return_value='524288'), patch.object(inotify.subprocess, 'run'):
                inotify.apply(config)
                first = config.read_text()
                inotify.apply(config)
            self.assertIn('vm.swappiness=80', first)
            backups = list(Path(directory).glob('*.backup-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), original)

    def test_failed_apply_restores_file(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'workstation.conf'
            original = 'vm.swappiness=80\n'
            config.write_text(original)
            failure = subprocess.CalledProcessError(1, 'sysctl')
            with patch.object(inotify.subprocess, 'check_output', return_value='8192'), patch.object(inotify.subprocess, 'run', side_effect=[failure, None]):
                with self.assertRaises(subprocess.CalledProcessError):
                    inotify.apply(config)
            self.assertEqual(config.read_text(), original)

    def test_failed_verification_removes_new_file(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'workstation.conf'
            with patch.object(inotify.subprocess, 'check_output', side_effect=['8192', '8192']), patch.object(inotify.subprocess, 'run'):
                with self.assertRaises(RuntimeError):
                    inotify.apply(config)
            self.assertFalse(config.exists())

    def test_malformed_existing_value_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'workstation.conf'
            config.write_text('fs.inotify.max_user_watches=unexpected\n')
            with patch.object(inotify.subprocess, 'check_output', return_value='8192'), patch.object(inotify.subprocess, 'run') as run:
                with self.assertRaises(ValueError):
                    inotify.apply(config)
                run.assert_not_called()

if __name__ == '__main__':
    unittest.main()
