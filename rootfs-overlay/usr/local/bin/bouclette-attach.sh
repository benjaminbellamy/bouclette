#!/bin/bash
# Called by udev: bouclette-attach.sh /dev/sda1
set -euo pipefail

DEVNAME="${1:-}"
MOUNT_POINT="/media/bouclette"
LOCKFILE="/run/bouclette.lock"
LOG="/tmp/bouclette.log"

[ -z "$DEVNAME" ] && exit 1

# First USB key wins — ignore subsequent insertions
if [ -f "$LOCKFILE" ]; then
  echo "$(date): Already playing from $(cat $LOCKFILE), ignoring $DEVNAME" >> "$LOG"
  exit 0
fi

# Record which device we're using
echo "$DEVNAME" > "$LOCKFILE"
echo "$(date): Attaching $DEVNAME" >> "$LOG"

# Mount read-only (any filesystem: FAT32, exFAT, NTFS)
mkdir -p "$MOUNT_POINT"
if ! mount -o ro,noatime "$DEVNAME" "$MOUNT_POINT" >> "$LOG" 2>&1; then
  echo "$(date): Mount failed for $DEVNAME" >> "$LOG"
  rm -f "$LOCKFILE"
  exit 1
fi

# Kill any idle screen
pkill -f bouclette-idle.sh 2>/dev/null || true

# Start the player
systemctl start bouclette-player.service >> "$LOG" 2>&1
