# Optional workstation changes

## TL;DR

The default script only raises the developer file-watch limit. Apply the steps
below separately after recording current settings. These commands are for the
Fedora workstation; they are not automatic optimizations or measured wins.

## DNF preferences

Inspect `/etc/dnf/dnf.conf` and back it up with `sudo cp -a --backup=numbered
/etc/dnf/dnf.conf /etc/dnf/dnf.conf.before-dotfiles` before editing. Keep
`max_parallel_downloads=2` as the existing preference until download measurements
justify another value. `fastestmirror=True` selects by connection latency, not
throughput. `defaultyes=True` changes the default confirmation choice, not speed.
For Fedora defaults remove those overrides only after reviewing the file. Verify
with `dnf --dump-main-config` (check the installed DNF version's help first).
Restore the saved file to roll back.

Reference: [DNF5 configuration](https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html).

## Power profile

Run `tuned-adm active` and `tuned-adm verify` in the actual host session. Record the
active profile before testing another. Keep the current profile by default.
If testing desktop scaling, first confirm `desktop` appears in `tuned-adm list`,
then run `sudo tuned-adm profile desktop`; verify and compare responsiveness and
idle power. Roll back with `sudo tuned-adm profile PREVIOUS_PROFILE`. A file in
`/etc/tuned` is not proof of live activation; do not disable other power managers
without understanding the host's integration.

## Services and boot

Measure `systemd-analyze critical-chain` and `systemd-analyze blame` first. Inspect
`systemctl list-dependencies --reverse NetworkManager-wait-online.service` and
whether network-dependent mounts/services need it. If demonstrated unnecessary,
record its enabled state, then use `sudo systemctl disable
NetworkManager-wait-online.service`; compare subsequent boots. Restore its
previous enabled state to roll back. Never blindly disable ModemManager, thermald,
rsyslog, abrtd, or lvm2-monitor; identify actual use and dependencies first.
Previously disabled services require individual review, not blanket re-enabling.

## AMD hardware video decoding

Inspect `rpm -q mesa-va-drivers mesa-va-drivers-freeworld` and `vainfo`; confirm
which codecs and driver the running application uses. A package's presence alone
does not establish active browser decoding. If needed, follow the current
[RPM Fusion codec instructions](https://rpmfusion.org/Howto/Multimedia) for the
installed Fedora release. Review a proposed DNF swap interactively; do not add
repositories or import keys silently. Record the transaction ID and package
versions. Review `sudo dnf history undo TRANSACTION_ID` to roll back; availability
of old packages can limit rollback. Do not claim codec acceleration until verified
in the application.

## Developer tools

Review and run `sudo dnf install fzf zoxide eza git-delta duf` separately. Verify
with `command -v` for each executable (`delta` is the git-delta executable).
Record the DNF transaction for rollback; avoid removing pre-existing tools.

## File-watch rollback

On success, the watch-limit helper prints any backup path. Restore that exact
file and apply just its watch-limit value with `sudo sysctl -w
fs.inotify.max_user_watches=PREVIOUS_VALUE`. If no file previously existed, remove
only the newly created workstation file and restore the previously recorded
kernel value. Do not apply every sysctl file as a shortcut to rollback.
