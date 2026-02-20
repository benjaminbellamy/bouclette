#!/bin/bash
# Called by udev: bouclette-detach.sh /dev/sda1
set -euo pipefail

DEVNAME="${1:-}"
MOUNT_POINT="/media/bouclette"
LOCKFILE="/run/bouclette.lock"
LOG="/tmp/bouclette.log"

[ -z "$DEVNAME" ] && exit 1

# Only act if this is the device we're currently using
CURRENT="$(cat "$LOCKFILE" 2>/dev/null || echo '')"
[ "$CURRENT" != "$DEVNAME" ] && exit 0

echo "$(date): Detaching $DEVNAME" >> "$LOG"

# Stop player
systemctl stop bouclette-player.service >> "$LOG" 2>&1 || true

# Unmount lazily (device is already gone)
umount -l "$MOUNT_POINT" >> "$LOG" 2>&1 || true

# Release lock
rm -f "$LOCKFILE"

# Show idle screen
/usr/local/bin/bouclette-idle.sh &
