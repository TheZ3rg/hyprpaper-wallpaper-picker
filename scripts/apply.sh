#!/usr/bin/env bash
#
# Apply a wallpaper through hyprpaper and persist it for the next login.
#
# Usage:
#   apply.sh <imagePath> [fit_mode] [hyprpaperConf]
#
# fit_mode: cover | contain | tile | fill

set -euo pipefail

IMG="${1:?usage: apply.sh <image> [fit_mode] [conf]}"
FIT="${2:-cover}"
CONF="${3:-$HOME/.config/hypr/hyprpaper.conf}"

[ -f "$IMG" ] || {
    echo "apply.sh: not a file: $IMG" >&2
    exit 1
}

# 1. Apply immediately through hyprpaper's IPC (0.8.x syntax).
if command -v hyprctl >/dev/null 2>&1 && pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprctl hyprpaper wallpaper ",$IMG,$FIT" >/dev/null 2>&1 || true
fi

# 2. Persist so hyprpaper restores it on next login (0.8 `wallpaper {}` block).
if [ -f "$CONF" ] && grep -q '^wallpaper[[:space:]]*{' "$CONF" 2>/dev/null; then
    tmp="$(mktemp)"
    awk -v img="$IMG" -v fit="$FIT" '
        /^wallpaper[[:space:]]*\{/ { inblk = 1 }
        inblk && /^[[:space:]]*path[[:space:]]*=/     { print "    path = " img; next }
        inblk && /^[[:space:]]*fit_mode[[:space:]]*=/ { print "    fit_mode = " fit; next }
        { print }
        inblk && /^[[:space:]]*\}/ { inblk = 0 }
    ' "$CONF" > "$tmp"
    mv -- "$tmp" "$CONF"
else
    mkdir -p "$(dirname -- "$CONF")"
    {
        printf 'wallpaper {\n'
        printf '    monitor =\n'
        printf '    path = %s\n' "$IMG"
        printf '    fit_mode = %s\n' "$FIT"
        printf '}\n'
    } >> "$CONF"
fi

# 3. Theme regeneration is intentionally not wired up yet. When ready, run the
#    Material You pipeline here, e.g.:
#        matugen image "$IMG" --mode dark --source-color-index 0

exit 0
