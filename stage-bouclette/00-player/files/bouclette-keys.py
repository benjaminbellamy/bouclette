#!/usr/bin/env python3
"""
bouclette-keys.py — Keyboard handler for the bouclette kiosk.
Reads raw key events from /dev/input and sends commands to mpv via IPC socket.
"""

import evdev
import selectors
import socket
import json
import os
import subprocess
import time

MPV_SOCKET = '/tmp/mpv.sock'

# key code → mpv IPC command (list)
MPV_COMMANDS = {
    evdev.ecodes.KEY_TAB:      ["cycle", "pause"],
    evdev.ecodes.KEY_PAGEUP:   ["add", "chapter", -1],
    evdev.ecodes.KEY_PAGEDOWN: ["add", "chapter",  1],
    evdev.ecodes.KEY_ENTER:    ["script-binding", "bouclette-toggle-osd"],
}

CEC_KEYS = {
    evdev.ecodes.KEY_VOLUMEUP:   "up",
    evdev.ecodes.KEY_VOLUMEDOWN: "down",
}


INTERESTING_KEYS = {
    evdev.ecodes.KEY_TAB,
    evdev.ecodes.KEY_ENTER,
    evdev.ecodes.KEY_PAGEUP,
    evdev.ecodes.KEY_PAGEDOWN,
    evdev.ecodes.KEY_VOLUMEUP,
    evdev.ecodes.KEY_VOLUMEDOWN,
}


def find_keyboards():
    keyboards = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            caps = dev.capabilities()
            if evdev.ecodes.EV_KEY not in caps:
                continue
            if set(caps[evdev.ecodes.EV_KEY]) & INTERESTING_KEYS:
                print(f"[keys] Found device: {dev.name} ({path})", flush=True)
                keyboards.append(dev)
        except Exception:
            pass
    return keyboards


def connect_mpv():
    while True:
        if os.path.exists(MPV_SOCKET):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(MPV_SOCKET)
                print("[keys] Connected to mpv IPC socket", flush=True)
                return s
            except Exception:
                pass
        time.sleep(1)


def mpv_send(sock, command):
    """Send a command to mpv. Raises on failure so the caller can reconnect."""
    msg = json.dumps({"command": command}) + "\n"
    sock.sendall(msg.encode())


def main():
    print("[keys] Waiting for mpv IPC socket...", flush=True)
    mpv_sock = connect_mpv()

    keyboards = find_keyboards()
    if not keyboards:
        print("[keys] No keyboards found — retrying in 5s", flush=True)
        time.sleep(5)
        keyboards = find_keyboards()

    sel = selectors.DefaultSelector()
    for dev in keyboards:
        sel.register(dev, selectors.EVENT_READ)

    print(f"[keys] Listening on {len(keyboards)} keyboard(s)", flush=True)

    while True:
        ready = sel.select(timeout=2)
        for key, _ in ready:
            dev = key.fileobj
            try:
                for event in dev.read():
                    if event.type != evdev.ecodes.EV_KEY:
                        continue
                    if event.value != 1:  # 1 = key down only
                        continue
                    code = event.code

                    if code in MPV_COMMANDS:
                        try:
                            mpv_send(mpv_sock, MPV_COMMANDS[code])
                        except Exception:
                            print("[keys] mpv socket lost — reconnecting", flush=True)
                            try:
                                mpv_sock.close()
                            except Exception:
                                pass
                            mpv_sock = connect_mpv()
                            try:
                                mpv_send(mpv_sock, MPV_COMMANDS[code])
                            except Exception:
                                pass

                    elif code in CEC_KEYS:
                        subprocess.Popen(
                            ["/usr/local/bin/bouclette-cec-volume.sh",
                             CEC_KEYS[code]],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )

            except OSError:
                # Keyboard device was unplugged
                sel.unregister(dev)
                keyboards.remove(dev)
                print(f"[keys] Device removed: {dev.path}", flush=True)


if __name__ == "__main__":
    main()
