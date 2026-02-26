#!/bin/bash
# Send a CEC volume key press to the TV over HDMI.
# Usage: bouclette-cec-volume.sh up|down

# Use the first available CEC device (cec0 = HDMI0 on RPi5)
DEV=""
for d in /dev/cec0 /dev/cec1 /dev/cec*; do
    [ -e "$d" ] && DEV="$d" && break
done
[ -z "$DEV" ] && exit 0

case "$1" in
    up)   KEY=41 ;;  # CEC Volume Up   (User Control Pressed)
    down) KEY=42 ;;  # CEC Volume Down (User Control Pressed)
    *)    exit 1 ;;
esac

# tx <src><dst>:<opcode>:<param>
#   src=1 (playback device), dst=0 (TV)
#   0x44 = User Control Pressed, 0x45 = User Control Released
printf "tx 10:44:%02x\ntx 10:45\n" "$KEY" | cec-client -s -d 1 "$DEV" 2>/dev/null
