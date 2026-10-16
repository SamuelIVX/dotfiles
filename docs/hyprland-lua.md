# Hyprland Lua migration and local Waybar

The Lua configuration targets Hyprland 0.56.2. It retains the ten-module structure,
63 shortcuts, seven startup entries, seven environment variables, five curves,
fifteen animations, and four window rules from `65283b2`. The original compositor
`.conf` files are frozen rollback references; Lua is the maintained configuration.
Hypridle and hyprlock still use their own `.conf` formats. Only hypridle's compositor
commands and the power menu's logout command change to Lua dispatch syntax.

## Current rollout state

Prepared in `~/dotfiles-lua` on `feat/hyprland-lua`, based on `65283b2`.
The live `~/.config` symlinks still point to `~/dotfiles`; they have not been changed.
An initial dereferenced snapshot of `hypr`, `waybar`, and `rofi`, with their original
symlink targets, is saved in `~/hyprland-before-lua-cEhS0z`. Refresh the snapshot at
the actual activation boundary if the live configurations change in the meantime.
Do not activate until the local Waybar build, requested CodeRabbit review, and
automated checks succeed. Build and live desktop acceptance remain pending.

Verified in this checkout: three existing shell suites, seventeen Python cases
(seven new integration/build cases), Lua preservation assertions for all 63
bindings/settings, and native Hyprland 0.56.2 parsing. A separate native probe
confirmed binding count, mouse-key registration, and repeat/lock flags. Lua drag
dispatchers handle releases themselves; the legacy `mouse` option is ignored by
0.56.2 and is deliberately omitted.

CodeRabbit was attempted twice after implementation; both attempts failed during
connection with `WebSocket closed`, before analysis. Logs are in
`/tmp/dotfiles-lua-coderabbit.ndjson` and `/tmp/dotfiles-lua-coderabbit-retry.ndjson`.
Diagnosis: `coderabbit doctor` passes runtime, storage, service URL configuration,
local authentication, and repository checks, but fails backend/WebSocket reachability.
Creating IPv4 TCP/UDP or IPv6 TCP sockets from the agent process returns
`PermissionError: [Errno 1] Operation not permitted`; DNS fails for CodeRabbit and
unrelated domains. This is an execution-environment network restriction, not evidence
of a broken host resolver or invalid login. Do not change DNS or clear credentials.
From a normal host terminal, run `coderabbit doctor`, then the review command below
from this checkout if its reachability checks pass.

Sam subsequently ran the doctor from the host terminal: all nine checks passed.
The complete migration review finished with `status: review_completed`,
`outcome: completed`, all 22 migration files listed as reviewed, and one `trivial`
finding in `tests/hyprland_integration.py`: the nohup mock recorded arguments but
did not execute the fake Waybar. The persisted CLI finding matches the supplied
completion output. The test now requires the selected executable's log entry;
that assertion failed before fixing the mock and passes afterward. The mock now
executes its arguments, and only the fake Waybar writes the completion marker.
The full suite passes after this change. Production configuration is unchanged
by this review fix. Sam explicitly waived the follow-up CLI review and requested
publishing the conversion PR. The completed review covered the pre-fix snapshot;
the subsequent test correction was reproduced and verified locally.

ShellCheck is not installed in the agent environment;
the expanded CI lint command still needs to run. Native Git sync is blocked by
SSH configuration ownership and sandbox networking; the authenticated GitHub
connector confirmed remote `main` still matches base `65283b2` before publication.
Live activation has not occurred. Waybar compilation and desktop acceptance remain
rollout requirements even after the PR is published.

## Build Waybar without replacing Fedora's package

The selected upstream revision is
[`8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9`](https://github.com/Alexays/Waybar/commit/8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9),
the merge of [config-provider detection](https://github.com/Alexays/Waybar/pull/5231).
It includes [Lua dispatch support](https://github.com/Alexays/Waybar/pull/5013).
Unpatched Waybar 0.14.0 and 0.15.0 predate those changes. Keep
`hyprland/workspaces`, persistent workspace buttons, current formatting, and CSS.

Install build prerequisites on the Fedora host, after checking the package transaction:

```bash
sudo dnf install gcc-c++ meson ninja-build cmake git pkgconf-pkg-config \
  gtkmm3.0-devel jsoncpp-devel wayland-devel wayland-protocols-devel \
  gtk-layer-shell-devel libxkbcommon-devel libdbusmenu-gtk3-devel \
  pulseaudio-libs-devel libnl3-devel fmt-devel spdlog-devel catch-devel shellcheck luajit jq
```

The current agent environment lacks the build toolchain and several development
packages, and the agent's network socket restriction prevents resolving repository hostnames. No package installation has
been performed. Meson may download checksum-pinned fallback dependencies from the
selected source revision; building requires network access when those are needed.

From the migration checkout:

```bash
bash scripts/build-waybar.sh
```

The builder checks tools and libraries, verifies the exact upstream commit and Lua
support, enables tray/audio/network support explicitly, compiles, runs upstream
tests, and stages installation before publishing it. CPU, memory, clock, custom,
and Hyprland modules are provided by the upstream build. A successful run installs:

```text
~/.local/opt/waybar-8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9/
~/.local/opt/waybar-lua -> waybar-8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9
```

`UPSTREAM_COMMIT` records provenance. The builder never restarts the running bar.
Startup uses the shared launcher with `--start`; Super+R and the full desktop
reload use its restart mode. All select `~/.local/opt/waybar-lua/bin/waybar`, with
no fallback to an incompatible system binary. Missing builds fail before killing
the running bar. Future updates must deliberately change the pinned revision,
rerun tests, and retain the previous installation/selection for rollback.

## Automated verification and review

```bash
bash tests/run.sh
Hyprland --verify-config --config "$PWD/.config/hypr/hyprland.lua"
shellcheck .config/hypr/scripts/{wallpaper,reload}.sh \
  .config/waybar/scripts/launch.sh \
  .config/rofi/scripts/{wifi,clipboard_history,wallpaper,powermenu}.sh \
  scripts/{apply-system-optimizations,build-waybar}.sh tests/*.sh
```

Tests require Python 3, LuaJIT, jq, and Bash. ShellCheck is also required for lint.
The Lua checks assert settings, commands, every binding and its flags, curves,
animations, rules, and startup-only execution. Shell integration checks use mocks
and temporary homes, including homes with spaces. Build tests exercise failure
before selection and successful staged installation; they do not compile Waybar.
Native parser verification is separate and required on the target compositor.

After the entire implementation and automated validation, review the complete
change, including new files:

```bash
coderabbit review --agent --uncommitted --include-untracked
```

Inspect the review scope for credentials before sending it. Record the reviewed
revision/diff and completed status. Independently check findings, fix actionable
issues within this migration, rerun all checks, and run at most one follow-up
review after fixes. A skipped review, quota error, or authentication failure does
not establish a completed review. Skills: Ponytail full, migration, code-review,
and receiving-code-review.

## Apply at a fresh-login boundary

First build Waybar and complete checks/review. Save work in applications before
the planned logout; no script automatically logs out or switches configuration
providers. Do not run the general installer to preview the staged migration.

Before activating, preserve snapshots of all three affected live directories and
record their symlink targets. These commands create a unique backup:

```bash
backup=$(mktemp -d "$HOME/hyprland-before-lua-XXXXXX")
for item in hypr waybar rofi; do
  cp -aL -- "$HOME/.config/$item" "$backup/$item"
  readlink "$HOME/.config/$item" > "$backup/$item.link" || true
done
readlink "$HOME/.local/opt/waybar-lua" > "$backup/waybar-selection" || true
printf 'Rollback snapshot: %s\n' "$backup"
```

The migration checkout must remain at its reviewed revision. Recheck that the live
paths are still the expected symlinks into `~/dotfiles`, and snapshot any edits
made after the baseline. At the logout boundary, switch only those three symlinks
to the corresponding directories in `~/dotfiles-lua`; leave other configurations
and shell/Git setup alone. Log in again to apply environment and startup behavior.
Lua takes priority over `.conf`, so simply retaining legacy files does not select
the old parser. Explicit `--config`/`HYPRLAND_CONFIG` overrides must select Lua too.

## Desktop acceptance and rollback

Require `hyprctl systeminfo` to report `configProvider: lua` and
`hyprctl configerrors` to be empty. Inspect registered bindings with `hyprctl binds`.
Verify monitor mode/refresh/scale/VRR; all application, focus, workspace, mouse,
media and screenshot shortcuts; floating tools and dialogs; animations; wallpapers
on workspaces 1–5 and retained images on 6–10; clipboard; lock; DPMS resume; suspend
recovery; Waybar workspace clicks, window title, tray, audio, network, notifications,
and power menu. Repeated reloads must retain exactly one set of session services
and bindings. These checks require a real desktop and cannot be inferred from mocks.

For failure recovery, use a TTY if necessary. Preserve the failed configuration,
replace the three migration symlinks with links to `$backup/hypr`, `$backup/waybar`,
and `$backup/rofi`, and log in again. Restore all three: idle/logout commands and
Waybar launchers must match the legacy parser. The snapshot's old launchers use the
packaged `/usr/bin/waybar`; the user-local build can remain installed and inactive.
To restore the original checkout links later, first ensure that checkout still
contains the saved legacy configuration, then use the recorded `.link` targets.

Do not delete the frozen `.conf` files or snapshots as part of this rollout.
