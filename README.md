# Bouclette

![Bouclette](bouclette.svg)

**bouclette** \bu.klɛt\ *féminin*  
Petite boucle de poils ou de cheveux. *(Small curl of hair or fur.)*

A Raspberry Pi 4/5 kiosk appliance that turns any USB key into a looping video player — no configuration, no desktop environment, no fuss.

Insert a USB key containing video files. Playback starts automatically, loops forever, and stops when you remove the key.

Inspired by [videolooper.de](http://videolooper.de/) and [Adafruit Pi Video Looper](https://github.com/adafruit/pi_video_looper), both of which rely on omxplayer — a player that has since been deprecated and removed from Raspberry Pi OS. Bouclette is built on mpv instead, and adds a heads-up display (chapter progress bar, pie chart, chapter list) and support for navigating chapters and files with a regular €10 PC remote.

---

## Features

- **Plug and play** — any USB key, any format (FAT32, exFAT, NTFS), no labeling required
- **Fullscreen, hardware-accelerated** playback via mpv (vo=gpu, hwdec=v4l2m2m)
- **Loops forever** — plays all video files alphabetically, then starts over
- **Hot-plug** — insert or remove the USB key at any time
- **MKV chapter navigation** via PC remote (Page Up / Page Down)
- **Real-time OSD overlay** — chapter progress bar, global pie chart, chapter list
- **CEC volume control** — controls TV/AVR volume over HDMI, falls back to software volume
- **Idle screen** — dark blue waiting screen when no USB key is present

---

## Hardware

- Raspberry Pi 4 or 5
- Raspberry Pi OS Lite 64-bit (Bookworm) — pi-gen stage2
- Any USB key containing video files at its root
- HDMI display
- USB PC remote (keyboard-type HID, sends PgUp/PgDn keycodes) — optional

---

## Supported Video Formats

`.mkv`, `.mp4`, `.avi`, `.mov`, `.webm`

---

## USB Key Preparation

No special setup required:

1. Use any USB key (FAT32, exFAT, or NTFS)
2. Copy your video files to the **root** of the key
3. Insert into the Raspberry Pi — playback starts automatically

Files are played in **alphabetical order**. Prefix filenames with numbers (`01-intro.mkv`, `02-main.mkv`) to control the order.

---

## Remote Control

| Key | Action |
|-----|--------|
| Page Up | Previous chapter |
| Page Down | Next chapter |
| Tab | Play / Pause |
| Left | Previous file |
| Right | Next file |
| Volume Up | Volume up (CEC → TV/AVR, or software fallback) |
| Volume Down | Volume down |
| Q / Escape | Quit (remove for strict kiosk lockdown) |

---

## Chapter Navigation

Chapters must be embedded in MKV files. The overlay and chapter navigation read them directly from the file metadata.

### Embed chapters with FFmpeg

Create a `chapters.txt` file:

```
CHAPTER01=00:00:00.000
CHAPTER01NAME=Intro
CHAPTER02=00:02:30.000
CHAPTER02NAME=Part 2
```

Embed into MKV (no re-encode):

```bash
ffmpeg -i input.mp4 -i chapters.txt -map_metadata 1 -map_chapters 1 -codec copy output.mkv
```

### Verify chapters are embedded

```bash
ffprobe -v quiet -print_format json -show_chapters input.mkv | python3 -m json.tool
```

---

## Recommended Encoding

For best results on Raspberry Pi hardware, encode video files as H.264 in an MKV container with chapters embedded.

```bash
ffmpeg \
  -i input.mp4 \
  -i chapters.txt \
  -map 0 \
  -map_chapters 1 \
  -c:v libx264 \
  -preset slow \
  -crf 22 \
  -profile:v high \
  -level 4.1 \
  -c:a aac \
  -b:a 192k \
  -movflags +faststart \
  output.mkv
```

| Option | Value | Reason |
|--------|-------|--------|
| `-c:v libx264` | H.264 | Hardware-decoded on RPi 4/5 (v4l2m2m) |
| `-crf 22` | Quality | 18–28 range; lower = larger file, better quality |
| `-preset slow` | Encoding speed | Better compression at the same quality |
| `-profile:v high -level 4.1` | Compatibility | Supported by RPi hardware decoder |
| `-c:a aac -b:a 192k` | Audio | Widely compatible, good quality |
| `-movflags +faststart` | Streaming | Moves metadata to the front of the file |
| `-map_chapters 1` | Chapters | Embeds chapters from `chapters.txt` |

The `chapters.txt` format (OGG/FFmpeg style):

```
CHAPTER01=00:00:00.000
CHAPTER01NAME=Intro
CHAPTER02=00:02:30.000
CHAPTER02NAME=Part 2
CHAPTER03=00:08:15.000
CHAPTER03NAME=Conclusion
```

If your source is already H.264 and you only want to add chapters without re-encoding:

```bash
ffmpeg -i input.mp4 -i chapters.txt -map 0 -map_chapters 1 -codec copy output.mkv
```

---

## Getting Started

There are three ways to get Bouclette onto an SD card:

| | [Releases](https://github.com/benjaminbellamy/bouclette/releases) | [INSTALL.md](INSTALL.md) | [BUILD.md](BUILD.md) |
|---|---|---|---|
| **Approach** | Flash the pre-built image | Flash official RPi OS Lite, configure over SSH | Build a custom image from scratch with pi-gen |
| **Time** | ~5 min | ~5 min + package download on the Pi | 20–60 min on the laptop |
| **Requirements** | Raspberry Pi Imager | SSH access, internet on the Pi | Linux laptop, ~8 GB disk, build tools |
| **Result** | Ready to use | Configured Pi | Ready-to-flash `.img.xz` |
| **Best for** | Just want it to work | Single install, quick setup | Reproducible deployment, multiple units |

---

## CEC Volume Control

Both RPi 4 and 5 support HDMI-CEC natively via `/dev/cec0`.

**Important:** always use the HDMI port closest to the USB-C power connector — CEC is unreliable on the other port.

To prevent the Pi from waking the TV on boot, add to `/boot/firmware/config.txt`:

```
hdmi_ignore_cec_init=1
```

If the TV is connected through an AV receiver, update the target address in `volume.lua` (logical address 5 for AVR instead of 0 for TV).

---

## Behavior Reference

| Situation | Behavior |
|-----------|----------|
| Boot, no USB | Idle screen |
| USB inserted | Auto-mount → loop all videos |
| USB removed | Stop player → idle screen |
| USB re-inserted | Restart from beginning |
| Second USB inserted while playing | Ignored (first key wins) |
| No video files on USB | Idle screen |
| End of last file | Loop back to first file |

---

## Troubleshooting

```bash
# Watch udev events as you insert the USB key
sudo udevadm monitor --subsystem-match=block --property

# Check what udev sees for a device
sudo udevadm info --query=all --name=/dev/sda1

# Check the player log
cat /tmp/bouclette.log

# Check the systemd service
systemctl status bouclette-player.service
journalctl -u bouclette-player.service -f

# Test mpv manually
mpv --fullscreen --loop-playlist=inf \
  --input-conf=/opt/mpv/input.conf \
  /media/bouclette/*.mkv

# Simulate a USB insert
sudo /usr/local/bin/bouclette-attach.sh /dev/sda1

# List block devices
lsblk -o NAME,TRAN,FSTYPE,LABEL,SIZE,MOUNTPOINT
```

---

## Repository Structure

```
bouclette/
├── build/
│   └── build-image.sh                         ← builds the RPi OS image
└── rootfs-overlay/
    ├── etc/
    │   ├── udev/rules.d/
    │   │   └── 99-bouclette.rules             ← USB hot-plug rules
    │   └── systemd/system/
    │       └── bouclette-player.service        ← mpv player service
    ├── usr/local/bin/
    │   ├── bouclette-attach.sh                ← called by udev on USB insert
    │   ├── bouclette-detach.sh                ← called by udev on USB remove
    │   ├── bouclette-play.sh                  ← main player script
    │   └── bouclette-idle.sh                  ← idle screen
    └── opt/mpv/
        ├── input.conf                         ← key bindings
        └── scripts/
            ├── volume.lua                     ← CEC volume with software fallback
            └── overlay.lua                    ← real-time chapter progress overlay
```

---

## License

GPL — see <https://www.gnu.org/licenses/gpl-3.0.html>
