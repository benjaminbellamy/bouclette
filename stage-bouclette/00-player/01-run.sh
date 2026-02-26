#!/bin/bash -e

BOOT="${ROOTFS_DIR}/boot/firmware"

# ── Player scripts ────────────────────────────────────────────────────────────
install -m 755 files/bouclette-player.sh     "${ROOTFS_DIR}/usr/local/bin/bouclette-player.sh"
install -m 755 files/bouclette-keys.py       "${ROOTFS_DIR}/usr/local/bin/bouclette-keys.py"
install -m 755 files/bouclette-cec-volume.sh "${ROOTFS_DIR}/usr/local/bin/bouclette-cec-volume.sh"

# ── mpv key bindings ──────────────────────────────────────────────────────────
mkdir -p "${ROOTFS_DIR}/etc/mpv"
install -m 644 files/input.conf "${ROOTFS_DIR}/etc/mpv/input.conf"

# ── systemd service ───────────────────────────────────────────────────────────
install -m 644 files/bouclette.service "${ROOTFS_DIR}/lib/systemd/system/bouclette.service"

on_chroot << EOF
systemctl enable bouclette.service
systemctl disable getty@tty1.service || true
EOF

# ── Runtime directories ───────────────────────────────────────────────────────
mkdir -p "${ROOTFS_DIR}/media/usb"
mkdir -p "${ROOTFS_DIR}/var/lib/bouclette"

# ── Boot: suppress console noise ─────────────────────────────────────────────
CMDLINE="${BOOT}/cmdline.txt"
if [ -f "${CMDLINE}" ]; then
	sed -i 's/console=tty1 //' "${CMDLINE}"
	sed -i 's/$/ quiet loglevel=3 logo.nologo vt.global_cursor_default=0/' "${CMDLINE}"
fi

# ── config.txt: kiosk tweaks ─────────────────────────────────────────────────
CONFIG="${BOOT}/config.txt"
if [ -f "${CONFIG}" ]; then
	cat >> "${CONFIG}" << 'CONF'

# Bouclette kiosk settings
disable_splash=1
boot_delay=0
hdmi_force_hotplug=1
CONF
fi

# ── cloud-init: write working network config ──────────────────────────────────
# pi-gen's default network-config is all commented out → cloud-init hangs on boot.
# We replace it with a config that enables ethernet (and WiFi if credentials were set).
cat > "${BOOT}/network-config" << 'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
EOF

if [ -n "${WPA_ESSID}" ]; then
	cat >> "${BOOT}/network-config" << EOF
  wifis:
    wlan0:
      dhcp4: true
      optional: true
      access-points:
        "${WPA_ESSID}":
          password: "${WPA_PASSWORD}"
      regulatory-domain: ${WPA_COUNTRY:-FR}
EOF
fi

# Minimal user-data: we don't need cloud-init to do anything on first boot
# (pi-gen already created the user, enabled SSH, set the hostname, etc.).
cat > "${BOOT}/user-data" << 'EOF'
#cloud-config
EOF
