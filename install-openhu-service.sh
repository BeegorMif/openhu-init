#!/usr/bin/env bash
# Install a systemd service that starts OpenHU directly on the Pi's HDMI display.
# Usage: ./install-openhu-service.sh [workspace-directory] [username]
# Defaults: ~/openhu and the invoking non-root user.

set -Eeuo pipefail

BASE_DIR="${1:-${OPENHU_WORKSPACE:-$HOME/openhu}}"
BASE_DIR="$(cd "$BASE_DIR" && pwd -P)"

if [[ -n "${2:-}" ]]; then
    OPENHU_USER="$2"
elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    OPENHU_USER="$SUDO_USER"
elif [[ "$(id -u)" -ne 0 ]]; then
    OPENHU_USER="$(id -un)"
else
    echo "ERROR: run this as your normal user, or pass the account name as the second argument." >&2
    exit 1
fi

if ! id "$OPENHU_USER" >/dev/null 2>&1; then
    printf 'ERROR: user does not exist: %s\n' "$OPENHU_USER" >&2
    exit 1
fi

USER_HOME="$(getent passwd "$OPENHU_USER" | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    printf 'ERROR: cannot find home directory for %s.\n' "$OPENHU_USER" >&2
    exit 1
fi

APP=""
for candidate in \
    "$BASE_DIR/openhu/build-release/bin/openhu" \
    "$BASE_DIR/openhu/build/bin/openhu" \
    /usr/libexec/openhu/openhu \
    /usr/bin/openhu; do
    if [[ -x "$candidate" ]]; then
        APP="$candidate"
        break
    fi
done

if [[ -z "$APP" ]]; then
    printf 'ERROR: OpenHU executable not found. Build or install OpenHU first.\n' >&2
    printf 'Looked in %s/openhu/build-release/bin, %s/openhu/build/bin, /usr/libexec/openhu, and /usr/bin.\n' \
        "$BASE_DIR" "$BASE_DIR" >&2
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

APP_DIR="$(dirname "$APP")"
WORK_DIR="$USER_HOME/.config/openhu"
GROUPS=()
for group in video render input; do
    if getent group "$group" >/dev/null; then
        GROUPS+=("$group")
    fi
done
GROUP_LINE=""
if ((${#GROUPS[@]})); then
    GROUP_LINE="SupplementaryGroups=${GROUPS[*]}"
fi

TMP_UNIT="$(mktemp)"
trap 'rm -f "$TMP_UNIT"' EXIT
cat >"$TMP_UNIT" <<EOF
[Unit]
Description=OpenHU on the local HDMI display (EGLFS)
# Do not wait for systemd-user-sessions: on Raspberry Pi OS that gate can
# follow NetworkManager and delay the display. OpenHU can start before Wi-Fi.
After=systemd-logind.service
Conflicts=getty@tty1.service
After=getty@tty1.service

[Service]
Type=simple
User=$OPENHU_USER
WorkingDirectory=$WORK_DIR
Environment=HOME=$USER_HOME
Environment=QT_QPA_PLATFORM=eglfs
ExecStart=$APP
Restart=on-failure
RestartSec=3
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
$GROUP_LINE

[Install]
WantedBy=multi-user.target
EOF

"${SUDO[@]}" install -d -o "$OPENHU_USER" -g "$(id -gn "$OPENHU_USER")" -m 0755 "$WORK_DIR"
"${SUDO[@]}" install -o root -g root -m 0644 "$TMP_UNIT" /etc/systemd/system/openhu-eglfs.service
"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" systemctl enable --now openhu-eglfs.service

cat <<EOF

Installed and started openhu-eglfs.service for $OPENHU_USER.
OpenHU executable: $APP
OpenHU data directory: $WORK_DIR

Useful commands:
  sudo systemctl status openhu-eglfs.service
  sudo journalctl -u openhu-eglfs.service -b
  sudo systemctl disable --now openhu-eglfs.service
EOF
