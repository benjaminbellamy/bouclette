#!/bin/bash
# Display a dark blue screen with a waiting message when no USB key is present.

# Kill any previous idle instance
pkill -f bouclette-idle.sh 2>/dev/null || true

# Hide cursor
setterm --cursor off 2>/dev/null || true

# Dark blue background (#000040) with centered message using tput
# Set background color via ANSI escape (closest to #000040: dark blue)
printf '\033[0;34m'       # dark blue foreground (fallback)
printf '\033[48;2;0;0;64m'  # true-color background: RGB(0, 0, 64) = #000040
printf '\033[38;2;180;180;255m'  # light blue-white text

clear

# Print centered message
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)
MSG="Waiting for USB key with video files…"
COL=$(( (COLS - ${#MSG}) / 2 ))
ROW=$(( ROWS / 2 ))

tput cup "$ROW" "$COL" 2>/dev/null || printf "\n\n\n"
printf "%s" "$MSG"

# Keep colors applied — sleep indefinitely until killed by bouclette-attach.sh
exec sleep infinity
