#!/usr/bin/env bash
#
# Scan a wallpaper folder, generate/cache thumbnails, and print a manifest to
# stdout, one line per wallpaper:
#
#     <sourcePath>\t<thumbPath>\t<thumbWidth>\t<thumbHeight>
#
# Usage:
#   sync-thumbs.sh <wallpaperDir> <cacheDir> <cover|preserve> <w> <h> <ext,ext,...> [cornerRadius]
#
# Thumbnails are keyed by the MD5 of the source path and regenerated when the
# source is newer. When cornerRadius > 0 the corners are rounded and baked into
# a PNG (so no runtime masking is needed). The cache is safe to delete.

set -uo pipefail

DIR="${1:-}"
CACHE="${2:-}"
MODE="${3:-cover}"
W="${4:-420}"
H="${5:-640}"
EXTS="${6:-jpg,jpeg,png,webp}"
RADIUS="${7:-0}"

if [ -z "$DIR" ] || [ -z "$CACHE" ]; then
    echo "sync-thumbs.sh: missing arguments" >&2
    exit 2
fi
if [ ! -d "$DIR" ]; then
    echo "sync-thumbs.sh: wallpaper dir not found: $DIR" >&2
    exit 0
fi

mkdir -p "$CACHE" 2>/dev/null || true

# Build the find -iname expression list from the extension argument.
find_args=()
first=1
IFS=',' read -ra exts <<< "$EXTS"
for e in "${exts[@]}"; do
    [ -z "$e" ] && continue
    if [ "$first" -eq 0 ]; then find_args+=( -o ); fi
    find_args+=( -iname "*.${e}" )
    first=0
done
if [ "${#find_args[@]}" -eq 0 ]; then
    find_args+=( -iname "*.jpg" )
fi

have_magick=0
command -v magick >/dev/null 2>&1 && have_magick=1

# Rounded corners -> PNG (alpha); otherwise JPEG.
if [ "$RADIUS" -gt 0 ] 2>/dev/null; then
    EXT="png"
else
    EXT="jpg"
fi

# List of cache entries produced by this scan, used to prune orphans below.
used_list="$(mktemp)"
: > "$used_list"
# Source-path hashes of the wallpapers that exist now (for backdrop pruning).
src_list="$(mktemp)"
: > "$src_list"

find "$DIR" -maxdepth 1 -type f \( "${find_args[@]}" \) -print0 2>/dev/null |
    sort -z |
    while IFS= read -r -d '' f; do
        # Cache key includes the generation options so changing mode/size/radius
        # regenerates the thumbnails instead of reusing stale ones.
        key="$(printf '%s' "$f|$MODE|${W}x${H}|r${RADIUS}" | md5sum | cut -d' ' -f1)"
        out="$CACHE/$key.$EXT"
        printf '%s\n' "$key.$EXT" >> "$used_list"
        printf '%s\n' "$(printf '%s' "$f" | md5sum | cut -d' ' -f1)" >> "$src_list"
        tmp=""

        if [ "$have_magick" -eq 1 ] && { [ ! -f "$out" ] || [ "$f" -nt "$out" ]; }; then
            tmp="$(mktemp --suffix=.png)"
            if [ "$MODE" = "preserve" ]; then
                magick "$f[0]" -thumbnail "${W}x${H}>" "$tmp" >/dev/null 2>&1 || true
            else
                magick "$f[0]" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" "$tmp" >/dev/null 2>&1 || true
            fi

            if [ -s "$tmp" ]; then
                if [ "$RADIUS" -gt 0 ] 2>/dev/null; then
                    rw="$(magick identify -format '%w' "$tmp[0]" 2>/dev/null || echo "$W")"
                    rh="$(magick identify -format '%h' "$tmp[0]" 2>/dev/null || echo "$H")"
                    magick "$tmp" \
                        \( -size "${rw}x${rh}" xc:none -fill white \
                           -draw "roundrectangle 0,0 $((rw - 1)),$((rh - 1)) ${RADIUS},${RADIUS}" \) \
                        -alpha off -compose CopyOpacity -composite "$out" >/dev/null 2>&1 || cp -f "$tmp" "$out"
                else
                    magick "$tmp" -quality 85 "$out" >/dev/null 2>&1 || cp -f "$tmp" "$out"
                fi
            fi
            rm -f "$tmp"
        fi

        shown="$out"
        [ -f "$shown" ] || shown="$f"

        dims=""
        if [ "$have_magick" -eq 1 ]; then
            dims="$(magick identify -format '%w %h' "$shown[0]" 2>/dev/null || true)"
        fi
        # shellcheck disable=SC2086
        set -- $dims
        printf '%s\t%s\t%s\t%s\n' "$f" "$shown" "${1:-$W}" "${2:-$H}"
    done

# Prune cache entries this scan did not produce: removed/renamed wallpapers and
# thumbnails made with old generation options. Only when the source dir exists,
# so a temporarily unavailable folder does not wipe the cache.
if [ -d "$DIR" ]; then
    while IFS= read -r cached; do
        [ -n "$cached" ] || continue
        if ! grep -qxF -- "$(basename -- "$cached")" "$used_list"; then
            rm -f -- "$cached"
        fi
    done < <(find "$CACHE" -maxdepth 1 -type f -print 2>/dev/null)

    # Prune baked backdrops whose source wallpaper no longer exists.
    if [ -d "$CACHE/backdrops" ]; then
        while IFS= read -r bd; do
            [ -n "$bd" ] || continue
            base="$(basename -- "$bd")"
            if ! grep -qxF -- "${base%%_*}" "$src_list"; then
                rm -f -- "$bd"
            fi
        done < <(find "$CACHE/backdrops" -maxdepth 1 -type f -print 2>/dev/null)
    fi
fi
rm -f "$used_list" "$src_list"
