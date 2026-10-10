# Wallpaper picker

A standalone Quickshell wallpaper picker: a fullscreen coverflow strip of your
wallpapers. It runs as its **own Quickshell instance** (separate process), so it
never touches the bar's shell.

## Usage

| Input | Action |
| --- | --- |
| `SUPER + W` | open / close the picker (toggles) |
| `←` / `→` | move the selection |
| mouse scroll | move the selection |
| `Enter` or click | apply the selected wallpaper and close |
| `Esc` | close without applying |

It opens on the focused monitor, shows the current wallpaper dimmed behind the
strip, and quits when closed (no background process).

## How it works

- **Launcher:** `scripts/open-picker.sh` (called by the Hyprland bind). If the
  picker is already running it closes it via IPC, otherwise it starts
  `qs -p ~/dev/projects/linux-rice`.
- **Scan + thumbnails:** `WallpaperModel.qml` runs `scripts/sync-thumbs.sh`,
  which lists `Config.wallpaperDir`, generates cached thumbnails (ImageMagick)
  and prints a manifest the model parses. Thumbnails live in
  `~/.cache/qs-wallpaper-picker/` and are rebuilt automatically; you can delete
  the folder at any time.
- **UI:** `WallpaperPicker.qml` (the fullscreen layer window) + `WallpaperStrip.qml`
  (the coverflow). Items are positioned by their *scaled* width, which gives the
  tight, tapered look toward the edges.
- **Apply:** `scripts/apply.sh` sets the wallpaper through hyprpaper's IPC and
  rewrites the `wallpaper {}` block in `hyprpaper.conf` so it is restored on
  login. No animated wallpapers.

## Configuration

Everything is in `Config.qml`:

- `wallpaperDir` — the folder to scan (single folder, not recursive).
- `extensions` — which file extensions count as wallpapers.
- `thumbnails.mode` — `"cover"` (fixed portrait crop) or `"preserve"` (keep each
  image's aspect ratio).
- `thumbnails.width` / `height` / `cornerRadius` — cache size and corner rounding
  (`0` = rectangular strips).
- `itemHeightRatio` — how tall the centred item is (fraction of screen height).
- `coverflow.enabled` / `centerScale` / `edgeScale` / `falloffRange` /
  `spacingRatio` — the coverflow look; set `enabled: false` for a flat strip.
- `backdrop` — `"wallpaper"` (blurred current wallpaper, default) or `"desktop"`
  (blur the live desktop/windows via ext-background-effect-v1).
- `backgroundDim` / `backgroundBlur` — backdrop dim and wallpaper blur radius.
- `topMargin` — inset below the bar so the bar stays visible above the overlay.
- `fitMode` — hyprpaper `fit_mode` (`cover`, `contain`, `tile`, `fill`).
- `regenerateTheme` — reserved for regenerating the Material You palette on
  apply (not wired up yet).

## Manual run

```bash
qs -p ~/dev/projects/linux-rice
```
