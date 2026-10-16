#!/usr/bin/env bash
# Build one upstream revision with required desktop modules, then select it locally.
set -euo pipefail
revision=8ebc788e802b1bf0d96b53e4b3815a9cee8a67c9
opt_dir="$HOME/.local/opt"
prefix="$opt_dir/waybar-$revision"
selected="$opt_dir/waybar-lua"

# Never replace a directory or an unrelated file at the selection path.
if [[ -e $selected && ! -L $selected ]]; then
    echo "Refusing to replace non-symlink: $selected" >&2
    exit 1
fi
for tool in git meson ninja pkg-config c++ cmake; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool (see docs/hyprland-lua.md)" >&2; exit 1; }
done
pkg-config --exists gtkmm-3.0 jsoncpp wayland-client wayland-cursor wayland-protocols \
    gtk-layer-shell-0 xkbregistry dbusmenu-gtk3-0.4 libpulse libnl-3.0 libnl-genl-3.0 \
    || { echo 'Missing Waybar development libraries (see docs/hyprland-lua.md).' >&2; exit 1; }
mkdir -p "$opt_dir"
build_root=$(mktemp -d "$opt_dir/.waybar-build-XXXXXX")
trap 'rm -rf -- "$build_root"' EXIT

if [[ -e $prefix ]]; then
    [[ -x $prefix/bin/waybar && -f $prefix/UPSTREAM_COMMIT && $(cat "$prefix/UPSTREAM_COMMIT") == "$revision" ]] \
        || { echo "Incomplete or unrecognized installation: $prefix" >&2; exit 1; }
else
    git init -q "$build_root/source"
    git -C "$build_root/source" fetch --depth 1 https://github.com/Alexays/Waybar.git "$revision"
    git -C "$build_root/source" checkout --detach FETCH_HEAD
    [[ $(git -C "$build_root/source" rev-parse HEAD) == "$revision" ]]
    # Check the selected source rather than trusting a release version string.
    grep -Fq 'isLuaConfigProvider' "$build_root/source/src/modules/hyprland/backend.cpp"
    grep -Fq 'hl.dsp.focus' "$build_root/source/src/modules/hyprland/backend.cpp"
    meson setup "$build_root/build" "$build_root/source" --prefix "$prefix" \
        --buildtype release -Ddbusmenu-gtk=enabled -Dpulseaudio=enabled -Dlibnl=enabled \
        -Dsystemd=disabled -Dman-pages=disabled -Dtests=enabled
    meson compile -C "$build_root/build"
    meson test -C "$build_root/build" --print-errorlogs
    # Stage installation so a failed install cannot leave a selectable partial prefix.
    DESTDIR="$build_root/install" meson install -C "$build_root/build"
    staged_prefix="$build_root/install$prefix"
    "$staged_prefix/bin/waybar" --version
    printf '%s\n' "$revision" > "$staged_prefix/UPSTREAM_COMMIT"
    mv -T -- "$staged_prefix" "$prefix"
fi
ln -s -- "$prefix" "$build_root/selected"
mv -Tf -- "$build_root/selected" "$selected"
printf 'Selected %s\nNo running Waybar process was restarted.\n' "$prefix/bin/waybar"
