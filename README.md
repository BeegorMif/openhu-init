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

Start OpenHU in a desktop session:

```bash
mkdir -p ~/.config/openhu
cd ~/.config/openhu
openhu
```

The repository syncs these project sources:

- [BeegorMif/openhu](https://github.com/BeegorMif/openhu)
- [BeegorMif/openhu-os](https://github.com/BeegorMif/openhu-os)
- [BeegorMif/openhu-plugins](https://github.com/BeegorMif/openhu-plugins)
- [BeegorMif/aasdk](https://github.com/BeegorMif/aasdk), compatible branch `openhu`
