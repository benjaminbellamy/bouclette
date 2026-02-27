# bouclette

![Bouclette](bouclette.svg)

> **bouclette** \bu.klɛt\ *féminin*  
Petite boucle de poils ou de cheveux. *(Small curl of hair or fur.)*

A Raspberry Pi 4/5 kiosk appliance that boots directly into a fullscreen video player.  
No desktop, no login prompt — just plug in a USB drive with video files and it plays.

Inspired by [videolooper.de](http://videolooper.de/) and [Adafruit Pi Video Looper](https://github.com/adafruit/pi_video_looper), both of which rely on omxplayer — a player that has since been deprecated and removed from Raspberry Pi OS. Bouclette is built on [mpv](https://mpv.io/) instead, and adds a heads-up display (chapter progress bar, circular progress indicator, chapter list) and support for navigating chapters and files with a regular €10 PC remote.

## What it does

- Plays all video files found on a USB drive (`mp4`, `mkv`, `avi`, `mov`, `ts`,
  `webm`, `flv`, `m4v`, `wmv`) in alphabetical order, looping forever
- Waits for a USB drive to appear at boot; resumes automatically if it is
  unplugged and reinserted
- Renders directly on the HDMI framebuffer via DRM/KMS — no X11 or Wayland

## Keyboard shortcuts

|Button    | Key       | Action                        |
|----------|-----------|-------------------------------|
|◻         | `Tab`     | Play / Pause video            |
|◻ ×2      | `ENTER`   | Hide / Display informations   |
|△         | `Page Up` | Previous chapter              |
|▽         | `Page Down` | Next chapter                |
|⊕         | `Vol +`   | Volume up (sent via HDMI CEC) |
|⊖         | `Vol -`   | Volume down (sent via HDMI CEC) |

A USB presentation remote (~€10) works perfectly as a wireless controller.

## Flash

Download the latest image from the [releases page](https://github.com/benjaminbellamy/bouclette/releases), unzip it and flash it to a microSD card:

```bash
unzip pi-gen/deploy/bouclette-*.zip
# replace /dev/sdX with your card device
sudo dd if=bouclette-*.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Or use the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (v2.0.4
or later) and select the `.img` file with "Use custom".

## Maintenance

The system is accessible over SSH:

```
ssh bouclette@bouclette.local
```

Default password: `bouclette`

Playback logs are available with:

```
journalctl -u bouclette -f
```
