# Installing Bouclette on an Existing Raspberry Pi OS Image

This is the quickest way to get Bouclette running: start from the official
Raspberry Pi OS Lite image, flash it, then configure it with a single script
over SSH. No build tools required on your laptop.

> If you want a fully pre-configured image that needs no internet access on the
> Pi, see [BUILD.md](BUILD.md) instead.

---

## 1. Flash Raspberry Pi OS Lite

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to download
and flash **Raspberry Pi OS Lite 64-bit (Bookworm)** in one step. Imager
handles the download, decompression, and verification automatically.

In the **OS Customisation** panel (gear icon ⚙), set:

| Setting | Value |
|---------|-------|
| Hostname | `bouclette` |
| Username | `pi` |
| Password | choose one |
| Enable SSH | ✓ (password or key) |
| Wi-Fi | optional — only needed for the install step |

Write to your SD card, then insert it into the Pi and power on.

---

## 2. Copy the Bouclette files

From your laptop, with the Pi reachable on the network:

```bash
git clone <repo-url> ~/bouclette

# Copy the rootfs overlay onto the Pi
rsync -av --rsync-path="sudo rsync" \
  ~/bouclette/rootfs-overlay/ \
  pi@bouclette.local:/
```

---

## 3. Run the setup script

SSH into the Pi and run:

```bash
ssh pi@bouclette.local
```

Then on the Pi:

```bash
sudo bash << 'EOF'
set -e

# Install required packages
apt-get update
apt-get install -y mpv exfat-fuse ntfs-3g v4l-utils

# Create required directories
mkdir -p /media/bouclette /opt/mpv/scripts

# Make scripts executable
chmod +x /usr/local/bin/bouclette-attach.sh \
         /usr/local/bin/bouclette-detach.sh \
         /usr/local/bin/bouclette-play.sh \
         /usr/local/bin/bouclette-idle.sh

# Set ownership
chown -R pi:pi /opt/mpv

# Reload udev rules
udevadm control --reload-rules

# Enable systemd service
systemctl daemon-reload

# Disable services not needed (faster boot)
systemctl disable bluetooth.service avahi-daemon.service triggerhappy.service 2>/dev/null || true

# Auto-login pi on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
AUTOLOGIN

# Show idle screen on login
grep -qxF '/usr/local/bin/bouclette-idle.sh &' /home/pi/.bash_profile \
  || echo '/usr/local/bin/bouclette-idle.sh &' >> /home/pi/.bash_profile

EOF
```

---

## 4. Reboot

```bash
sudo reboot
```

The Pi will boot directly to the idle screen. Insert a USB key with video
files — playback starts automatically.

---

## Updating

To push updated scripts to an already-running Pi:

```bash
rsync -av --rsync-path="sudo rsync" \
  ~/bouclette/rootfs-overlay/ \
  pi@bouclette.local:/

ssh pi@bouclette.local "sudo udevadm control --reload-rules && sudo systemctl daemon-reload"
```
