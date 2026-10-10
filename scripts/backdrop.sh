#!/usr/bin/env bash
#
# Generate (and cache) a blurred, screen-sized backdrop from a wallpaper.
# Prints the path of the cached image on stdout.
#
# Usage:
#   backdrop.sh <sourceImage> <cacheDir> <width> <height> <blurRadius>
#
# The image is cover-cropped to <width>x<height> (1:1 with the screen) and then
# blurred with edge-clamped virtual pixels, so there is no transparent fade at
# the screen edges (which is what a runtime blur effect would produce).
# Cached by md5(source|radius|WxH); safe to delete.

set -euo pipefail

SRC="${1:-}"
CACHE="${2:-}"
W="${3:-2560}"
H="${4:-1440}"
RADIUS="${5:-0}"

if [ -z "$SRC" ] || [ -z "$CACHE" ]; then
    echo "backdrop.sh: missing arguments" >&2
    exit 2
fi
if [ ! -f "$SRC" ]; then
    echo "backdrop.sh: not a file: $SRC" >&2
    exit 0
fi

command -v magick >/dev/null 2>&1 || {
    echo "backdrop.sh: ImageMagick (magick) not found" >&2
    exit 0
}

# Backdrops live in their own subdir so the thumbnail cache pruning can't touch them.
OUT_DIR="$CACHE/backdrops"
mkdir -p "$OUT_DIR"

# Map the user-facing blur amount to an ImageMagick sigma. The live fallback
# (Qt MultiEffect) produces a noticeably weaker blur than magick for the same
# number, and the two looked different when the fallback briefly showed while
# the baked image was generated. Dividing by ~3 makes them match.
SIGMA=0
if [ "$RADIUS" -gt 0 ] 2>/dev/null; then
    SIGMA=$(( RADIUS / 3 ))
    [ "$SIGMA" -lt 1 ] && SIGMA=1
fi

key="$(printf 'v2|%s|%s|%sx%s' "$SRC" "$RADIUS" "$W" "$H" | md5sum | cut -d' ' -f1)"
srchash="$(printf '%s' "$SRC" | md5sum | cut -d' ' -f1)"
out="$OUT_DIR/${srchash}_r${RADIUS}_${W}x${H}_${key:0:8}.jpg"

if [ ! -f "$out" ] || [ "$SRC" -nt "$out" ]; then
    tmp="$(mktemp --suffix=.jpg)"
    if [ "$SIGMA" -gt 0 ]; then
        magick "$SRC" \
            -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
            -virtual-pixel edge -blur "0x${SIGMA}" \
            -strip -quality 90 "$tmp"
    else
        magick "$SRC" \
            -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
            -strip -quality 90 "$tmp"
    fi
    mv -- "$tmp" "$out"
fi

printf '%s\n' "$out"
