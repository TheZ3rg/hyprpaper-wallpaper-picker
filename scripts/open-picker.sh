#!/usr/bin/env bash
#
# Toggle the wallpaper picker.
#   - if it is already running, ask it to close (via IPC)
#   - otherwise launch its own Quickshell instance
#
# This is what the SUPER + W keybind calls.

set -uo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v qs >/dev/null 2>&1 && qs ipc -p "$DIR" call wallpaperPicker close >/dev/null 2>&1; then
    exit 0
fi

exec qs -p "$DIR"
