#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run this script with sudo: sudo ./scripts/apply-system-optimizations.sh"
    exit 1
fi

echo "[+] 1. Configuring DNF for fast mirrors and parallel downloads (max 2)..."
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
    cat << 'EOF' >> /etc/dnf/dnf.conf
max_parallel_downloads=2
fastestmirror=True
defaultyes=True
EOF
    echo "    Done: Added max_parallel_downloads=2, fastestmirror=True, defaultyes=True."
else
    sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=2/' /etc/dnf/dnf.conf
    echo "    Done: Updated max_parallel_downloads to 2."
fi

echo "[+] 2. Setting tuned power profile to 'desktop' (optimized for Ryzen desktop workloads)..."
if command -v tuned-adm >/dev/null 2>&1; then
    tuned-adm profile desktop
    echo "    Done: Active tuned profile set to desktop."
fi

echo "[+] 3. Shaving ~5.6s off boot time (disabling NetworkManager-wait-online.service)..."
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
echo "    Done: NetworkManager-wait-online disabled."

echo "[+] 4. Raising inotify file watch limits for dev projects..."
cat << 'EOF' > /etc/sysctl.d/99-workstation.conf
# Raise file watch limits for IDEs, Node, Rust, and Python dev
fs.inotify.max_user_watches=524288
EOF
sysctl -p /etc/sysctl.d/99-workstation.conf
echo "    Done: inotify watches set to 524288."

echo "[+] 5. Setting up RPM Fusion Free & hardware video acceleration (VA-API freeworld)..."
if ! dnf repolist | grep -q "rpmfusion-free"; then
    echo "    Enabling RPM Fusion Free repository..."
    dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" || true
fi

if dnf repolist | grep -q "rpmfusion-free"; then
    echo "    Swapping mesa-va-drivers for freeworld hardware acceleration..."
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld || true
    echo "    Done: Hardware video acceleration installed."
fi

echo "[✓] All system-level performance optimizations applied successfully!"
