#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIGEN_DIR="${SCRIPT_DIR}/pi-gen"
PIGEN_REPO="https://github.com/RPi-Distro/pi-gen.git"

# ── Defaults: config.default, optionally overridden by config ────────────────
# shellcheck source=config.default
source "${SCRIPT_DIR}/config.default"
if [ -f "${SCRIPT_DIR}/config" ]; then
    # shellcheck source=config
    source "${SCRIPT_DIR}/config"
fi

# ── Build-mode flags (not in config) ─────────────────────────────────────────
CLEAN=0
NATIVE=0

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat << EOF
Usage: $0 [options]

Build options:
  --clean             Wipe the pi-gen work directory before building
  --native            Native build (requires root) instead of Docker

Image configuration (defaults from config.default):
  --img-name NAME         Image file name          [$IMG_NAME]
  --release RELEASE       Debian release           [$RELEASE]
  --arch ARCH             arm64 or armhf           [$IMG_ARCH]
  --hostname NAME         mDNS hostname            [$TARGET_HOSTNAME]
  --locale LOCALE         System locale            [$LOCALE_DEFAULT]
  --timezone TZ           Timezone                 [$TIMEZONE_DEFAULT]
  --keyboard-keymap MAP   Keyboard keymap          [$KEYBOARD_KEYMAP]
  --keyboard-layout LAYOUT  Keyboard layout        [$KEYBOARD_LAYOUT]
  --user NAME             Default username         [$FIRST_USER_NAME]
  --password PASS         Default password         [$FIRST_USER_PASS]
  --ssh / --no-ssh        Enable or disable SSH    [$([ "$ENABLE_SSH" = "1" ] && echo enabled || echo disabled)]
  --wpa-essid SSID        WiFi network name        [${WPA_ESSID:-(empty)}]
  --wpa-password PASS     WiFi password            [${WPA_PASSWORD:-(empty)}]
  --wpa-country CC        WiFi country code        [$WPA_COUNTRY]
EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)              CLEAN=1 ;;
        --native)             NATIVE=1 ;;
        --img-name)           IMG_NAME="$2";         shift ;;
        --release)            RELEASE="$2";          shift ;;
        --arch)               IMG_ARCH="$2";         shift ;;
        --hostname)           TARGET_HOSTNAME="$2";  shift ;;
        --locale)             LOCALE_DEFAULT="$2";   shift ;;
        --timezone)           TIMEZONE_DEFAULT="$2"; shift ;;
        --keyboard-keymap)    KEYBOARD_KEYMAP="$2";  shift ;;
        --keyboard-layout)    KEYBOARD_LAYOUT="$2";  shift ;;
        --user)               FIRST_USER_NAME="$2";  shift ;;
        --password)           FIRST_USER_PASS="$2";  shift ;;
        --ssh)                ENABLE_SSH=1 ;;
        --no-ssh)             ENABLE_SSH=0 ;;
        --wpa-essid)          WPA_ESSID="$2";        shift ;;
        --wpa-password)       WPA_PASSWORD="$2";     shift ;;
        --wpa-country)        WPA_COUNTRY="$2";      shift ;;
        -h|--help)            usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# ── Clone pi-gen once ────────────────────────────────────────────────────────
if [ ! -d "${PIGEN_DIR}" ]; then
    echo "Cloning pi-gen..."
    git clone --depth 1 "${PIGEN_REPO}" "${PIGEN_DIR}"
fi

# ── Write pi-gen config from current variables ───────────────────────────────
echo "Syncing config and stage-bouclette into pi-gen..."
cat > "${PIGEN_DIR}/config" << EOF
IMG_NAME="${IMG_NAME}"
RELEASE="${RELEASE}"
DEPLOY_COMPRESSION="${DEPLOY_COMPRESSION}"

LOCALE_DEFAULT="${LOCALE_DEFAULT}"
KEYBOARD_KEYMAP="${KEYBOARD_KEYMAP}"
KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT}"
TIMEZONE_DEFAULT="${TIMEZONE_DEFAULT}"

TARGET_HOSTNAME="${TARGET_HOSTNAME}"
FIRST_USER_NAME="${FIRST_USER_NAME}"
FIRST_USER_PASS="${FIRST_USER_PASS}"

ENABLE_SSH=${ENABLE_SSH}

WPA_ESSID="${WPA_ESSID}"
WPA_PASSWORD="${WPA_PASSWORD}"
WPA_COUNTRY="${WPA_COUNTRY}"

IMG_ARCH="${IMG_ARCH}"
DISABLE_FIRST_BOOT_USER_RENAME=${DISABLE_FIRST_BOOT_USER_RENAME}
STAGE_LIST="${STAGE_LIST}"
EOF

rm -rf "${PIGEN_DIR}/stage-bouclette"
cp -r "${SCRIPT_DIR}/stage-bouclette" "${PIGEN_DIR}/stage-bouclette"
chmod +x "${PIGEN_DIR}/stage-bouclette/prerun.sh"
chmod +x "${PIGEN_DIR}/stage-bouclette/00-player/01-run.sh"

# Suppress the stock stage2-lite image; only export the bouclette image
touch "${PIGEN_DIR}/stage2/SKIP_IMAGES"

# ── Optionally wipe work dir ─────────────────────────────────────────────────
if [ "${CLEAN}" = "1" ]; then
    echo "Wiping pi-gen work directory..."
    rm -rf "${PIGEN_DIR}/work"
fi

# ── Build ────────────────────────────────────────────────────────────────────
cd "${PIGEN_DIR}"

if [ "${NATIVE}" = "1" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Native build requires root. Run: sudo $0 --native"
        exit 1
    fi
    bash build.sh
else
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is not installed."
        echo "  Install Docker: https://docs.docker.com/engine/install/"
        echo "  Or use the native build: sudo $0 --native"
        exit 1
    fi
    bash build-docker.sh
fi

if [ -n "${SUDO_UID}" ]; then
    chown -R "${SUDO_UID}:${SUDO_GID}" "${PIGEN_DIR}/deploy/"
fi

echo ""
echo "=== Build complete. Image: ==="
ls -lh "${PIGEN_DIR}/deploy/"*.zip 2>/dev/null || echo "(no .zip in pi-gen/deploy/)"
