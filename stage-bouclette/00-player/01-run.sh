#!/bin/bash -e

BOOT="${ROOTFS_DIR}/boot/firmware"

# ── Player scripts ────────────────────────────────────────────────────────────
install -m 755 files/bouclette-player.sh     "${ROOTFS_DIR}/usr/local/bin/bouclette-player.sh"
install -m 755 files/bouclette-keys.py       "${ROOTFS_DIR}/usr/local/bin/bouclette-keys.py"
install -m 755 files/bouclette-cec-volume.sh "${ROOTFS_DIR}/usr/local/bin/bouclette-cec-volume.sh"

# ── mpv key bindings ──────────────────────────────────────────────────────────
mkdir -p "${ROOTFS_DIR}/etc/mpv"
install -m 644 files/input.conf "${ROOTFS_DIR}/etc/mpv/input.conf"

# ── OSD overlay script ────────────────────────────────────────────────────────
mkdir -p "${ROOTFS_DIR}/usr/local/lib/bouclette"
install -m 644 files/bouclette-osd.lua "${ROOTFS_DIR}/usr/local/lib/bouclette/bouclette-osd.lua"

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
if [ -f "${CMDLINE}" ] && ! grep -q "vt.global_cursor_default" "${CMDLINE}"; then
	sed -i 's/console=tty1 //' "${CMDLINE}"
	sed -i 's/$/ quiet loglevel=3 logo.nologo vt.global_cursor_default=0/' "${CMDLINE}"
fi

# ── config.txt: kiosk tweaks ─────────────────────────────────────────────────
CONFIG="${BOOT}/config.txt"
if [ -f "${CONFIG}" ] && ! grep -q "bouclette" "${CONFIG}"; then
	cat >> "${CONFIG}" << 'CONF'

# Bouclette kiosk settings
disable_splash=1
boot_delay=0
hdmi_force_hotplug=1
CONF
fi

# ── cloud-init: enable ethernet DHCP so SSH is reachable on first boot ────────
cat > "${BOOT}/network-config" << 'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
EOF

# ── WiFi: write NetworkManager connection file directly ───────────────────────
# This is exactly what Raspberry Pi Imager does — cloud-init's netplan renderer
# is unreliable with NetworkManager; writing the .nmconnection file directly works.
if [ -n "${WPA_ESSID}" ]; then
	CONNDIR="${ROOTFS_DIR}/etc/NetworkManager/system-connections"
	mkdir -p "${CONNDIR}"
	UUID=$(cat /proc/sys/kernel/random/uuid)
	cat > "${CONNDIR}/preconfigured.nmconnection" << EOF
[connection]
id=preconfigured
uuid=${UUID}
type=wifi

[wifi]
mode=infrastructure
ssid=${WPA_ESSID}
hidden=false

[wifi-security]
key-mgmt=wpa-psk
psk=${WPA_PASSWORD}

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF
	chmod 600 "${CONNDIR}/preconfigured.nmconnection"
	log "WiFi configured for SSID: ${WPA_ESSID}"
fi

# ── cloud-init: minimal user-data (pi-gen handles user/SSH/hostname already) ──
cat > "${BOOT}/user-data" << 'EOF'
#cloud-config
EOF
