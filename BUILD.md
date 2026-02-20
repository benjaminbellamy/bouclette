# Building the Bouclette Image

The SD card image is built on a Linux laptop using
[pi-gen](https://github.com/RPi-Distro/pi-gen), the official Raspberry Pi OS
image builder. The result is a ready-to-flash `.img.xz` file.

> **Platform:** Debian or Ubuntu host recommended. Other distros may work but
> are untested. Building on macOS or Windows is not supported.

---

## 1. Install dependencies

```bash
sudo apt install \
  git quilt parted qemu-user-static debootstrap zerofree \
  zip dosfstools libcap2-bin grep rsync xz-utils file
```

## 2. Clone pi-gen

```bash
git clone https://github.com/RPi-Distro/pi-gen.git ~/pi-gen
```

## 3. Clone this repository

```bash
git clone <repo-url> ~/bouclette
```

## 4. Build

```bash
cd ~/bouclette
./build/build-image.sh
```

The script will:

1. Write a `config` file into the pi-gen directory
2. Copy the `rootfs-overlay/` tree into pi-gen's stage2
3. Add a `stage-bouclette` stage that installs packages (`mpv`, `exfat-fuse`,
   `ntfs-3g`, `v4l-utils`) and configures auto-login and the systemd service
4. Run the pi-gen build (this takes **20–60 minutes** depending on your machine
   and internet connection)

If pi-gen is not at `~/pi-gen`, point to it explicitly:

```bash
PIGEN_DIR=/path/to/pi-gen ./build/build-image.sh
```

## 5. Flash the image

The finished image is in `~/pi-gen/deploy/`.

**Recommended:** use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) →
**"Use custom image"** → select the `.img.xz` file. Imager handles decompression,
verification, and safe unmount automatically.

Alternatively, with `dd`:

```bash
# Replace /dev/sdX with your SD card device — double-check with lsblk!
sudo dd if=~/pi-gen/deploy/bouclette-*.img.xz \
        of=/dev/sdX \
        bs=4M status=progress
sudo sync
```

---

## Rebuilding after changes

pi-gen caches each stage in `work/`. To rebuild only the bouclette stage after
changing scripts or config:

```bash
# Remove the cached bouclette stage, keep earlier stages cached
rm -rf ~/pi-gen/work/*/stage-bouclette
cd ~/bouclette && ./build/build-image.sh
```

To rebuild everything from scratch:

```bash
rm -rf ~/pi-gen/work ~/pi-gen/deploy
cd ~/bouclette && ./build/build-image.sh
```

---

## Troubleshooting

**`qemu-user-static` not found or binfmt not active**
```bash
sudo apt install qemu-user-static
sudo systemctl restart systemd-binfmt
```

**Build fails with "debootstrap error"**
Check your internet connection — debootstrap downloads packages from the
Raspberry Pi OS mirrors during the build.

**`mount: permission denied`**
pi-gen needs to run mount inside a chroot. Make sure you are not inside a
Docker container or a filesystem that disallows it. Run on a bare metal or
standard VM host.

**Out of disk space**
A full build requires ~8 GB of free space. The finished image is ~2 GB
compressed. Check with `df -h`.
