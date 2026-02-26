# Building a bouclette image

The image is built with [pi-gen](https://github.com/RPi-Distro/pi-gen), the
official Raspberry Pi OS build tool, targeting **Debian 13 (Trixie)** on
**arm64**. The `build-image.sh` script clones pi-gen, injects the bouclette
stage, and runs the build.

## Requirements

**Docker build (recommended):** Docker must be running. No root required.

**Native build:** Debian/Ubuntu host, root access, and the pi-gen dependencies:

```
sudo apt-get install coreutils quilt parted qemu-user-static debootstrap \
    zerofree zip dosfstools libcap2-bin grep rsync xz-utils file git curl
```

## Build

```bash
# First build (clones pi-gen, takes ~30–60 min)
./build-image.sh

# Subsequent builds reuse the pi-gen work directory (much faster)
./build-image.sh

# Force a full rebuild from scratch
./build-image.sh --clean

# Native build (requires root)
sudo ./build-image.sh --native
```

The final image is written to `pi-gen/deploy/` as a `.zip` file.

## Customisation

`config.default` is the committed template with safe defaults. Copy it to
`config` (gitignored) and fill in your credentials:

```bash
cp config.default config
$EDITOR config
```

`build-image.sh` sources `config.default` first, then `config` on top
of it — so `config` only needs to contain the values you actually want to
override.

Any value can also be overridden on the command line without editing files:

```bash
./build-image.sh --hostname kiosk-lobby --wpa-essid MyWifi --wpa-password s3cr3t
```

Run `./build-image.sh --help` for the full list of options.

The available variables are:

| Variable | Default | Description |
|---|---|---|
| `TARGET_HOSTNAME` | `bouclette` | mDNS hostname (`<name>.local`) |
| `FIRST_USER_NAME` | `bouclette` | SSH login |
| `FIRST_USER_PASS` | `bouclette` | SSH password — **change before shipping** |
| `LOCALE_DEFAULT` | `fr_FR.UTF-8` | System locale |
| `TIMEZONE_DEFAULT` | `Europe/Paris` | Timezone |
| `IMG_ARCH` | `arm64` | `arm64` for RPi4/5, `armhf` for RPi3 |
| `WPA_ESSID` | _(empty)_ | WiFi network name — leave empty to skip |
| `WPA_PASSWORD` | _(empty)_ | WiFi password |
| `WPA_COUNTRY` | `FR` | ISO 3166-1 country code for WiFi regulatory domain |
