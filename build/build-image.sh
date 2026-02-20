#!/bin/bash
# Builds a custom RPi OS Lite image (stage0–stage2 + stage-bouclette) with the video looper pre-installed.
# Run from the repo root: ./build/build-image.sh
#
# Optionally set PIGEN_DIR to point to your pi-gen clone:
#   PIGEN_DIR=~/pi-gen ./build/build-image.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIGEN_DIR="${PIGEN_DIR:-$HOME/pi-gen}"

if [ ! -d "$PIGEN_DIR" ]; then
  echo "ERROR: pi-gen not found at $PIGEN_DIR"
  echo "Clone it: git clone https://github.com/RPi-Distro/pi-gen.git $PIGEN_DIR"
  exit 1
fi

# --- pi-gen config ---
cat > "$PIGEN_DIR/config" <<EOF
IMG_NAME="bouclette"
RELEASE=bookworm
DEPLOY_COMPRESSION=xz
ENABLE_SSH=1
PUBKEY_SSH_FIRST_USER="$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo '')"
FIRST_USER_NAME=pi
FIRST_USER_PASS=bouclette
HOSTNAME=bouclette
KEYBOARD_KEYMAP=us
KEYBOARD_LAYOUT="English (US)"
TIMEZONE_DEFAULT=Europe/Paris
LOCALE_DEFAULT=en_GB.UTF-8
WPA_COUNTRY=FR
EOF

# Skip desktop stages (stage3–stage5); stage2 = Raspberry Pi OS Lite
touch "$PIGEN_DIR/stage3/SKIP"
touch "$PIGEN_DIR/stage4/SKIP"
touch "$PIGEN_DIR/stage5/SKIP"

# --- Copy rootfs overlay into stage2 ---
rsync -av --delete \
  "$REPO_ROOT/rootfs-overlay/" \
  "$PIGEN_DIR/stage2/rootfs/"

# --- Custom stage: install packages and configure services ---
STAGE_DIR="$PIGEN_DIR/stage-bouclette"
mkdir -p "$STAGE_DIR"

# Packages to install
cat > "$STAGE_DIR/00-packages" <<'EOF'
mpv
exfat-fuse
ntfs-3g
v4l-utils
EOF

cat > "$STAGE_DIR/01-run.sh" <<'STAGESCRIPT'
#!/bin/bash -e
on_chroot << 'EOF'
  # Create required directories
  mkdir -p /media/bouclette /opt/mpv

  # Make scripts executable
  chmod +x /usr/local/bin/bouclette-attach.sh
  chmod +x /usr/local/bin/bouclette-detach.sh
  chmod +x /usr/local/bin/bouclette-play.sh
  chmod +x /usr/local/bin/bouclette-idle.sh

  # Set ownership
  chown -R pi:pi /home/pi /opt/mpv

  # Disable services we don't need (faster boot)
  systemctl disable bluetooth.service 2>/dev/null || true
  systemctl disable avahi-daemon.service 2>/dev/null || true
  systemctl disable triggerhappy.service 2>/dev/null || true

  # Auto-login pi user on tty1
  mkdir -p /etc/systemd/system/getty@tty1.service.d
  cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
AUTOLOGIN

  # Show idle screen on login (until USB is inserted)
  grep -qxF '/usr/local/bin/bouclette-idle.sh &' /home/pi/.bash_profile \
    || echo '/usr/local/bin/bouclette-idle.sh &' >> /home/pi/.bash_profile
EOF
STAGESCRIPT
chmod +x "$STAGE_DIR/01-run.sh"

# --- Build ---
echo "Starting pi-gen build (this takes a while)..."
cd "$PIGEN_DIR"
STAGE_LIST="stage0 stage1 stage2 stage-bouclette" sudo -E bash build.sh

echo ""
echo "Done! Image is in: $PIGEN_DIR/deploy/"
echo "Flash with:"
echo "  sudo dd if=deploy/bouclette-*.img of=/dev/sdX bs=4M status=progress"
echo "  or: rpi-imager"
