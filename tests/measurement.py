"""Check the documented benchmark's pairing without launching shell processes."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


class MeasurementTests(unittest.TestCase):
    """Keep the executable measurement instructions aligned with their claims."""
    def test_variants_alternate_within_twenty_pairs(self) -> None:
        """Alternate first position to avoid collecting one variant as a batch."""
        document = Path(__file__).resolve().parents[1] / 'docs/performance-baseline.md'
        code = document.read_text().split('```python\n', 1)[1].split('```', 1)[0]
        commands = []
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.bashrc').write_text('fastfetch\n')
            def capture(args: list[str], **kwargs: object) -> subprocess.CompletedProcess:
                """Capture each variant instead of starting an actual shell."""
                commands.append(Path(args[3]).name)
                return subprocess.CompletedProcess(args, 0)
            with patch.object(Path, 'home', return_value=home), patch.object(subprocess, 'run', side_effect=capture), redirect_stdout(io.StringIO()):
                exec(compile(code, str(document), 'exec'), {})
        self.assertEqual(commands, ['current', 'without_fastfetch', 'without_fastfetch', 'current'] * 10)


if __name__ == '__main__':
    unittest.main()
