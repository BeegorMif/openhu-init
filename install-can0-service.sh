#!/usr/bin/env bash
# Install a boot-time SocketCAN setup service for OpenHU.
# Usage: ./install-can0-service.sh [bitrate] [interface]
# Defaults to 500000 bit/s on can0; existing configuration is preserved with no arguments.

set -Eeuo pipefail

CAN_BITRATE="${1:-500000}"
CAN_INTERFACE="${2:-can0}"

if [[ ! "$CAN_BITRATE" =~ ^[0-9]+$ ]] || ((10#$CAN_BITRATE == 0)); then
    printf 'ERROR: bitrate must be a positive number in bits per second: %s\n' "$CAN_BITRATE" >&2
    exit 1
fi
if [[ ! "$CAN_INTERFACE" =~ ^can[0-9]+$ ]]; then
    printf 'ERROR: invalid CAN interface name: %s\n' "$CAN_INTERFACE" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SETUP_SCRIPT="$SCRIPT_DIR/openhu-can0-setup"
UNIT_FILE="$SCRIPT_DIR/openhu-can0.service"
if [[ ! -r "$SETUP_SCRIPT" || ! -r "$UNIT_FILE" ]]; then
    echo "ERROR: openhu-can0-setup or openhu-can0.service is missing from this checkout." >&2
    exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=()
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "ERROR: install sudo or run this script as root." >&2
        exit 1
    fi
    SUDO=(sudo)
fi

CONFIG_FILE=/etc/default/openhu-can0
if [[ -e "$CONFIG_FILE" && $# -eq 0 ]]; then
    echo "Keeping existing CAN configuration in $CONFIG_FILE"
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    CAN_BITRATE="${CAN_BITRATE:-500000}"
    CAN_INTERFACE="${CAN_INTERFACE:-can0}"
else
    TMP_CONFIG="$(mktemp)"
    trap 'rm -f "$TMP_CONFIG"' EXIT
    cat >"$TMP_CONFIG" <<EOF
# OpenHU SocketCAN settings. CAN_BITRATE is in bits per second.
CAN_INTERFACE=$CAN_INTERFACE
CAN_BITRATE=$CAN_BITRATE
EOF
    "${SUDO[@]}" install -o root -g root -m 0644 "$TMP_CONFIG" "$CONFIG_FILE"
fi

if [[ ! "$CAN_BITRATE" =~ ^[0-9]+$ ]] || ((10#$CAN_BITRATE == 0)); then
    printf 'ERROR: bitrate in %s must be a positive number in bits per second.\n' "$CONFIG_FILE" >&2
    exit 1
fi
if [[ ! "$CAN_INTERFACE" =~ ^can[0-9]+$ ]]; then
    printf 'ERROR: invalid CAN interface name in %s: %s\n' "$CONFIG_FILE" "$CAN_INTERFACE" >&2
    exit 1
fi

"${SUDO[@]}" install -o root -g root -m 0755 "$SETUP_SCRIPT" /usr/local/sbin/openhu-can0-setup
"${SUDO[@]}" install -o root -g root -m 0644 "$UNIT_FILE" /etc/systemd/system/openhu-can0.service
"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" systemctl enable openhu-can0.service
"${SUDO[@]}" systemctl restart openhu-can0.service

cat <<EOF

Installed and started openhu-can0.service.
CAN interface: $CAN_INTERFACE
Bitrate: $CAN_BITRATE bit/s

If the bus uses a different rate, edit $CONFIG_FILE and restart with:
  sudo systemctl restart openhu-can0.service

Check status with:
  sudo systemctl status openhu-can0.service
  ip -details link show $CAN_INTERFACE
EOF
