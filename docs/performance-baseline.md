# Workstation performance baseline

## TL;DR

Preserve the current visuals and target balanced responsiveness. Configuration is
not a benchmark. The measurements below were captured in a restricted agent
sandbox, not a complete Hyprland session; no desktop performance gain is claimed.

## Recorded evidence

| Check | Observation | Limit |
|---|---|---|
| OS | Fedora 43 KDE edition | Read from host os-release |
| Memory/storage | About 30 GiB RAM, 8 GiB zram, Btrfs on NVMe | Snapshot, not a pressure test |
| Shell with current startup | 20 samples; median 39.32 ms; range 38.53–41.25 ms | Non-login interactive Bash, no PTY, output discarded |
| Shell without Fastfetch | 20 samples; median 33.95 ms; range 32.84–35.54 ms | Temporary rc file; original startup untouched |
| Fastfetch difference | 5.37 ms between medians | Sandbox observation only; retain current behavior |
| Codec package | mesa-va-drivers-freeworld installed; mesa-va-drivers absent | Package inventory does not prove application decoding |
| Power configuration | `/etc/tuned/active_profile`: balanced; EPP: balance_performance | Live TuneD activation could not be queried |
| Monitor/compositor | Unverified | Hyprland socket access denied |
| Boot/failed services | Unverified | System and user bus access denied |
| Desktop idle CPU/power | Unverified | Process visibility excludes the live desktop |

The historical samples above collected each variant as a separate batch. Cache
warm-up or changing host load can bias that difference. The repeat procedure
below interleaves variants and alternates first position within each pair; the
historical numbers have not been remeasured with this procedure.

## Repeat shell startup measurement

Run from your normal host terminal. This measures startup without terminal
rendering, so also compare perceived opening time in Kitty. The temporary variant
intercepts the direct Fastfetch startup invocation; it never edits dotfiles.

```python
import pathlib, statistics, subprocess, tempfile, time

original = pathlib.Path.home().joinpath('.bashrc').read_text()
with tempfile.TemporaryDirectory() as directory:
    variants = ('current', 'without_fastfetch')
    samples = {variant: [] for variant in variants}
    configs = {}
    for variant in variants:
        rc = pathlib.Path(directory) / variant
        # Intercept only direct fastfetch calls in this disposable child shell.
        # The tracked fragment and existing rc both use direct calls.
        rc.write_text(('fastfetch() { :; }\n' if variant == 'without_fastfetch' else '') + original)
        configs[variant] = rc
    for round_number in range(20):
        order = variants if round_number % 2 == 0 else variants[::-1]
        for variant in order:
            rc = configs[variant]
            start = time.perf_counter()
            subprocess.run(['bash', '--noprofile', '--rcfile', str(rc), '-ic', 'exit'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            samples[variant].append((time.perf_counter() - start) * 1000)
    for variant, values in samples.items():
        assert len(values) == 20
        print(variant, 'median/range ms:', statistics.median(values), min(values), max(values))
```

This temporary function does not intercept an explicit `command fastfetch` or
absolute executable path; inspect customized startup files before using it.
Retain Fastfetch unless repeated host measurements or your preference justify
moving it to an on-demand command.

## Complete the host baseline

- Capture `systemd-analyze`, `systemd-analyze critical-chain`, and failed system/user
  units across three comparable cold boots. Report medians and ranges, not a single
  longest service: services can start in parallel.
- Run `hyprctl monitors`, `hyprctl configerrors`, `tuned-adm active`, and
  `tuned-adm verify`. Confirm actual resolution/refresh and power-profile activation.
- Count `wallpaper.sh` listener processes after login and after ten `SUPER+A`
  refreshes. There should be one listener.
- With the same apps open and no builds/downloads, capture three sixty-second
  idle samples using `pidstat -u -r 1 60` if installed. Record compositor, bar,
  wallpaper, CPU activity, and available hardware power readings separately.
- Inspect `vainfo` and the browser's media diagnostics during the same video test.
  Confirm the codec, rendering/decoding device, CPU use, and dropped frames.

## Change policy

Keep blur, transparency, animations, VRR, Kitty delays, and wallpaper transition
rate unchanged in this series. Test one proposed tuning change at a time with the
same workload. Adopt it only if improvement is repeatable beyond baseline variation,
and record any visual, latency, or idle-power tradeoff plus rollback.
