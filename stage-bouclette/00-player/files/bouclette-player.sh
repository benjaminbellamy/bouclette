#!/bin/bash
# bouclette-player.sh — Infinite USB video player for kiosk

MOUNT_POINT=/media/usb
PLAYLIST_FILE=/tmp/bouclette-playlist.txt
MPV_SOCKET=/tmp/mpv.sock
WAITING_IMAGE=/var/lib/bouclette/waiting.png
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf

WAITING_PID=""

log() {
    echo "[bouclette] $*"
    echo "[bouclette] $*" > /dev/kmsg 2>/dev/null || true
}

find_drm_device() {
    for card in /dev/dri/card*; do
        cardname=$(basename "$card")
        if ls /sys/class/drm/${cardname}-HDMI-* 2>/dev/null | grep -q .; then
            echo "$card"
            return
        fi
    done
    echo "/dev/dri/card0"
}

find_usb_device() {
    for dev in /dev/sd?; do
        [ -b "$dev" ] || continue
        if [ -b "${dev}1" ]; then
            echo "${dev}1"
        else
            echo "$dev"
        fi
        return
    done
}

build_playlist() {
    find "$MOUNT_POINT" -type f \
        \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \
           -o -iname "*.mov" -o -iname "*.ts"  -o -iname "*.webm" \
           -o -iname "*.flv" -o -iname "*.m4v" -o -iname "*.wmv" \) \
        2>/dev/null | sort
}

generate_waiting_image() {
    mkdir -p /var/lib/bouclette
    ffmpeg -y -loglevel quiet \
        -f lavfi -i "color=c=0x001040:s=1920x1080:r=1" \
        -vf "drawtext=fontfile=${FONT}:fontsize=52:fontcolor=white:\
x=(w-text_w)/2:y=(h-text_h)/2:\
text='Please insert a USB key with video files.'" \
        -vframes 1 "$WAITING_IMAGE"
}

show_waiting() {
    [ -f "$WAITING_IMAGE" ] || return
    hide_waiting
    mpv \
        --vo=drm \
        --drm-device="$DRM_DEVICE" \
        --no-config \
        --really-quiet \
        --image-display-duration=inf \
        "$WAITING_IMAGE" &
    WAITING_PID=$!
}

hide_waiting() {
    if [ -n "$WAITING_PID" ]; then
        kill "$WAITING_PID" 2>/dev/null || true
        wait "$WAITING_PID" 2>/dev/null || true
        WAITING_PID=""
        sleep 0.5  # let DRM device be fully released
    fi
}

cleanup() {
    hide_waiting
    kill "$KEYS_PID" 2>/dev/null || true
}
trap cleanup EXIT

# ── Startup ──────────────────────────────────────────────────────────────────

DRM_DEVICE=$(find_drm_device)
log "Using DRM device: $DRM_DEVICE"

log "Generating waiting screen..."
generate_waiting_image && log "Waiting screen ready" \
    || log "Warning: could not generate waiting screen (ffmpeg/font issue)"

python3 /usr/local/bin/bouclette-keys.py &
KEYS_PID=$!
log "Key handler started (pid $KEYS_PID)"

# ── Main loop ─────────────────────────────────────────────────────────────────

while true; do
    show_waiting

    log "Waiting for USB video drive..."
    USB_DEV=""
    while [ -z "$USB_DEV" ]; do
        USB_DEV=$(find_usb_device)
        [ -z "$USB_DEV" ] && sleep 2
    done
    log "Found USB device: $USB_DEV"

    mkdir -p "$MOUNT_POINT"
    if ! mountpoint -q "$MOUNT_POINT"; then
        if ! mount -o ro "$USB_DEV" "$MOUNT_POINT" 2>/dev/null; then
            log "Failed to mount $USB_DEV — retrying in 3s"
            sleep 3
            continue
        fi
    fi
    log "Mounted $USB_DEV at $MOUNT_POINT"

    build_playlist > "$PLAYLIST_FILE"
    if [ ! -s "$PLAYLIST_FILE" ]; then
        log "No video files found on USB — retrying in 5s"
        umount "$MOUNT_POINT" 2>/dev/null || true
        sleep 5
        continue
    fi

    VIDEO_COUNT=$(wc -l < "$PLAYLIST_FILE")
    log "Playing $VIDEO_COUNT video file(s) in loop"

    hide_waiting
    rm -f "$MPV_SOCKET"
    mpv \
        --vo=drm \
        --drm-device="$DRM_DEVICE" \
        --hwdec=auto \
        --loop-playlist=inf \
        --playlist="$PLAYLIST_FILE" \
        --input-ipc-server="$MPV_SOCKET" \
        --input-conf=/etc/mpv/input.conf \
        --no-config \
        --really-quiet || true

    log "mpv exited — unmounting and retrying"
    umount "$MOUNT_POINT" 2>/dev/null || true
    sleep 2
done
