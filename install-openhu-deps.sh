#!/usr/bin/env bash
# Install the native ARM64 build dependencies for OpenHU on Debian/Raspberry Pi OS Trixie.
# Usage: ./install-openhu-deps.sh

set -Eeuo pipefail

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: cannot identify this operating system." >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
    printf 'ERROR: OpenHU currently documents Debian 13 Trixie; this system reports %s.\n' \
        "${VERSION_CODENAME:-unknown}" >&2
    echo "Use a Trixie-based 64-bit Raspberry Pi OS/Debian installation before building." >&2
    exit 1
fi

if [[ "$(dpkg --print-architecture)" != "arm64" ]]; then
    printf 'ERROR: this system is %s; an ARM64 (64-bit) installation is required.\n' \
        "$(dpkg --print-architecture)" >&2
    exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
    APT=(apt-get)
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "ERROR: install sudo or run this script as root." >&2
        exit 1
    fi
    APT=(sudo apt-get)
fi

"${APT[@]}" update
"${APT[@]}" install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    dpkg-dev \
    fakeroot \
    file \
    git \
    libavcodec-dev \
    libavutil-dev \
    libboost-log-dev \
    libboost-system-dev \
    libgps-dev \
    libprotobuf-dev \
    libssl-dev \
    libswscale-dev \
    libusb-1.0-0-dev \
    ninja-build \
    pkg-config \
    protobuf-compiler \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-virtualkeyboard \
    qml6-module-qtquick-window \
    qml6-module-qtmultimedia \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-declarative-dev-tools \
    qt6-l10n-tools \
    qt6-multimedia-dev \
    qt6-svg-plugins \
    qt6-virtualkeyboard-plugin \
    qt6-websockets-dev

cat <<'EOF'

Build dependencies are installed. Next, sync the sources and build OpenHU:
  ./update.sh ~/openhu
  cd ~/openhu/openhu
  ./build.sh release --aasdk-path ../aasdk-ref --package --output-dir ./packages

Then install the generated ARM64 packages:
  sudo apt install ./packages/libaasdk_*_arm64.deb ./packages/openhu_*_arm64.deb

This prepares OpenHU for testing on the Pi; it does not install an OpenHU OS image.
EOF
