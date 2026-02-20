#!/bin/bash
set -euo pipefail

MEDIA_DIR="/media/bouclette"
INPUT_CONF="/opt/mpv/input.conf"
LOG="/tmp/bouclette.log"

# Brief wait for filesystem to settle after mount
sleep 1

# Find video files at root of USB key, sorted alphabetically
mapfile -t FILES < <(find "$MEDIA_DIR" -maxdepth 1 \
  \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \
     -o -iname "*.mov" -o -iname "*.webm" \) \
  | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "$(date): No video files found on USB key" | tee -a "$LOG"
  /usr/local/bin/bouclette-idle.sh
  exit 0
fi

echo "$(date): Playing ${#FILES[@]} file(s):" | tee -a "$LOG"
printf '  %s\n' "${FILES[@]}" | tee -a "$LOG"

exec mpv \
  --really-quiet \
  --no-osd-bar \
  --no-osc \
  --cursor-autohide=always \
  --fullscreen \
  --loop-playlist=inf \
  --vo=gpu \
  --hwdec=v4l2m2m \
  --input-conf="$INPUT_CONF" \
  --scripts-dir=/opt/mpv/scripts \
  "${FILES[@]}"
