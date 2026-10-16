"""Exercise Lua dispatcher integration and Waybar selection without desktop access."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parents[1]
REVISION = "8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9"


class DesktopIntegrationTests(unittest.TestCase):
    """Use temporary homes and mock commands; never contact the real desktop."""

    def setUp(self) -> None:
        """Create an isolated command path and command-argument log."""
        self.temp = tempfile.TemporaryDirectory(prefix="lua desktop ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "calls"
        self.env = dict(os.environ, HOME=str(self.home), CALLS=str(self.log),
                        PATH=f"{self.bin}:/usr/bin:/bin")
        for name in ("hyprctl", "killall", "notify-send", "swaync"):
            self.command(name, 'printf "%s\\n" "$0" "$@" >> "$CALLS"\n')
        self.command("nohup", 'printf "%s\\n" "$0" "$@" >> "$CALLS"\nexec "$@"\n')
        self.command("rofi", 'cat >/dev/null\nprintf "%s" "${CHOICE:-}"\n')

    def command(self, name: str, body: str) -> None:
        """Write an executable shell mock into the isolated PATH."""
        path = self.bin / name
        path.write_text("#!/bin/bash\nset -eu\n" + body)
        path.chmod(0o755)

    def run_script(self, relative: str, *args: str, **changes: str) -> subprocess.CompletedProcess:
        """Run a repository script with mock commands and capture diagnostics."""
        return subprocess.run(["bash", str(REPO / relative), *args],
                              env=dict(self.env, **changes), capture_output=True, text=True, check=False)

    def install_bar(self) -> Path:
        """Provide a selected fake executable that records and signals actual startup."""
        bar = self.home / ".local/opt/waybar-lua/bin/waybar"
        bar.parent.mkdir(parents=True)
        bar.write_text('#!/bin/bash\nprintf "selected-waybar\\n" >> "$CALLS"\n: > "$HOME/bar-started"\n')
        bar.chmod(0o755)
        return bar

    def wait_for_bar(self) -> None:
        """Wait for the detached mock's completion marker rather than racing its log."""
        deadline = time.monotonic() + 3
        while not (self.home / "bar-started").exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertTrue((self.home / "bar-started").exists(), "detached bar did not start")

    def test_logout_and_cancel(self) -> None:
        """Logout passes one Lua expression; cancellation does not dispatch."""
        result = self.run_script(".config/rofi/scripts/powermenu.sh", CHOICE="󰍃  Log Out")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines()[1:], ["dispatch", "hl.dsp.exit()"])
        self.log.unlink()
        result = self.run_script(".config/rofi/scripts/powermenu.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())

    def test_idle_dispatchers_and_timeouts(self) -> None:
        """Exercise all three quoted DPMS commands and retain timeout boundaries."""
        text = (REPO / ".config/hypr/hypridle.conf").read_text()
        commands = [line.split("=", 1)[1].strip() for line in text.splitlines()
                    if "hyprctl" in line]
        self.assertEqual(len(commands), 3)
        for command, action in zip(commands, ("on", "off", "on")):
            self.log.unlink(missing_ok=True)
            result = subprocess.run(["bash", "-c", command], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.log.read_text().splitlines()[1:],
                             ["dispatch", f'hl.dsp.dpms({{ action = "{action}" }})'])
        timeouts = [int(line.split("=", 1)[1]) for line in text.splitlines()
                    if line.strip().startswith("timeout =")]
        self.assertEqual(timeouts, [150, 300, 360, 1800])

    def test_bar_selection_and_reload(self) -> None:
        """Startup/restart/full reload all use the same executable, including spaced homes."""
        bar = self.install_bar()
        launcher = ".config/waybar/scripts/launch.sh"
        result = self.run_script(launcher, "--start")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "selected-waybar\n")
        (self.home / "bar-started").unlink()
        self.log.unlink()
        result = self.run_script(launcher)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for_bar()
        self.assertIn(str(bar), self.log.read_text().splitlines())
        self.assertIn("selected-waybar", self.log.read_text().splitlines())
        launch_link = self.home / ".config/waybar/scripts/launch.sh"
        launch_link.parent.mkdir(parents=True)
        launch_link.symlink_to(REPO / launcher)
        (self.home / "bar-started").unlink()
        self.log.unlink()
        result = self.run_script(".config/hypr/scripts/reload.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for_bar()
        calls = self.log.read_text().splitlines()
        self.assertIn(str(bar), calls)
        self.assertIn("selected-waybar", calls)
        self.assertIn("reload", calls)

    def test_missing_bar_preserves_running_processes(self) -> None:
        """Fail before kill/reload when the compatible build has not been installed."""
        for script in (".config/waybar/scripts/launch.sh", ".config/hypr/scripts/reload.sh"):
            result = self.run_script(script)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(self.log.exists())
        self.assertEqual(self.run_script(".config/waybar/scripts/launch.sh", "--invalid").returncode, 2)

    def mock_build(self) -> None:
        """Emulate source verification, tests, and a staged installation of the pinned build."""
        for name in ("ninja", "pkg-config", "c++", "cmake"):
            self.command(name, "exit 0\n")
        self.command("git", f'''
if [[ $1 == init ]]; then mkdir -p "$3"; exit; fi
source=$2
case $3 in
    fetch) printf '%s\\n' "$@" >> "$CALLS" ;;
    checkout)
        mkdir -p "$source/src/modules/hyprland"
        printf 'isLuaConfigProvider hl.dsp.focus\\n' > "$source/src/modules/hyprland/backend.cpp" ;;
    rev-parse) printf '{REVISION}\\n' ;;
esac
''')
        self.command("meson", '''
printf '%s\\n' "$@" >> "$CALLS"
case $1 in
    setup)
        mkdir -p "$2"
        printf '%s' "$5" > "$HOME/build-prefix" ;;
    test) exit "${FAIL_TESTS:-0}" ;;
    install)
        prefix=$(cat "$HOME/build-prefix")
        mkdir -p "$DESTDIR$prefix/bin"
        printf '#!/bin/bash\\nexit 0\\n' > "$DESTDIR$prefix/bin/waybar"
        chmod +x "$DESTDIR$prefix/bin/waybar" ;;
esac
''')

    def test_build_selects_only_tested_pinned_install(self) -> None:
        """Successful build selects its exact revision and retains required module flags."""
        self.mock_build()
        result = self.run_script("scripts/build-waybar.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        selected = self.home / ".local/opt/waybar-lua"
        self.assertEqual(selected.resolve().name, f"waybar-{REVISION}")
        self.assertEqual((selected / "UPSTREAM_COMMIT").read_text().strip(), REVISION)
        calls = self.log.read_text().splitlines()
        for value in (REVISION, "-Ddbusmenu-gtk=enabled", "-Dpulseaudio=enabled", "-Dlibnl=enabled", "test"):
            self.assertIn(value, calls)
        self.assertEqual(self.run_script("scripts/build-waybar.sh").returncode, 0)

    def test_failed_build_does_not_replace_selection(self) -> None:
        """Failed upstream tests leave the previous executable selection intact."""
        self.mock_build()
        selected = self.home / ".local/opt/waybar-lua"
        selected.parent.mkdir(parents=True)
        selected.symlink_to("previous-waybar")
        result = self.run_script("scripts/build-waybar.sh", FAIL_TESTS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(os.readlink(selected), "previous-waybar")
        self.assertFalse((selected.parent / f"waybar-{REVISION}").exists())
        self.assertFalse(list(selected.parent.glob(".waybar-build-*")))

    def test_build_preflight_and_collision(self) -> None:
        """Missing libraries and selection-directory conflicts fail before fetching."""
        self.mock_build()
        self.command("pkg-config", "exit 1\n")
        result = self.run_script("scripts/build-waybar.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("development libraries", result.stderr)
        self.assertFalse(self.log.exists())
        selected = self.home / ".local/opt/waybar-lua"
        selected.mkdir(parents=True)
        (selected / "keep").write_text("preserve")
        result = self.run_script("scripts/build-waybar.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((selected / "keep").read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
