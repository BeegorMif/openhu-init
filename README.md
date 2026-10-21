# OpenHU Pi setup helpers

Small helper scripts for preparing a 64-bit Raspberry Pi OS / Debian Trixie system to build and test OpenHU.

## Requirements

- Raspberry Pi 4B or 5 running 64-bit Debian 13 (Trixie) or Raspberry Pi OS based on Trixie
- Internet access
- A user with `sudo` privileges

These scripts prepare and build the OpenHU application on Raspberry Pi OS. They do not create or install an
OpenHU OS image; the current `openhu-os` image configuration is still x86-64/UEFI.

## Use

Clone this helper repository and install the build packages:

```bash
git clone https://github.com/BeegorMif/openhu-init.git
cd openhu-init
./install-openhu-deps.sh
```

Clone or fast-forward the OpenHU repositories under `~/openhu`:

```bash
./sync-openhu-repos.sh ~/openhu
```

The sync script also checks out the compatible `BeegorMif/aasdk` branch `openhu`. It safely updates a clean
existing AASDK checkout from the previous `average-web-dev/aasdk` origin. It stops instead of overwriting local
changes or updating folders with an unexpected origin or branch.

Build OpenHU for the Pi's ARM64 OS:

```bash
cd ~/openhu/openhu
./build.sh release --aasdk-path ../aasdk-ref --package --output-dir ./packages
sudo apt install ./packages/libaasdk_*_arm64.deb ./packages/openhu_*_arm64.deb
```

On Raspberry Pi OS Lite, install a service to start OpenHU on the HDMI display with EGLFS:

```bash
./install-openhu-service.sh ~/openhu
```

The script enables and starts `openhu-eglfs.service` for the current user. It expects OpenHU to be built at
`~/openhu/openhu/build-release/bin/openhu` or installed at `/usr/libexec/openhu/openhu` (or `/usr/bin/openhu`).
It also installs or reloads OpenHU's USB udev rule so the service can access Android phones; reconnect a phone
that was already plugged in when the rule was installed.
Check startup with `sudo journalctl -u openhu-eglfs.service -b`; disable it with
`sudo systemctl disable --now openhu-eglfs.service`. EGLFS takes over tty1 and the HDMI display. The service waits
for logind and tty1, but not `systemd-user-sessions` or NetworkManager, so the display can start earlier while
network services finish loading.

The repository syncs these project sources:

- [BeegorMif/openhu](https://github.com/BeegorMif/openhu)
- [BeegorMif/openhu-os](https://github.com/BeegorMif/openhu-os)
- [BeegorMif/openhu-plugins](https://github.com/BeegorMif/openhu-plugins)
- [BeegorMif/aasdk](https://github.com/BeegorMif/aasdk), compatible branch `openhu`
