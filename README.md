# Wallpaper picker (hyprpaper)

A standalone Quickshell wallpaper picker: a fullscreen coverflow strip of your
wallpapers, applied through **hyprpaper**. It runs as its own Quickshell instance
(separate process), so it never touches the bar's shell.

> [!NOTE]
> This is the **hyprpaper** version. It works, but development has moved to
> [`hyprland-wallpaper-picker`](https://github.com/TheZ3rg/hyprland-wallpaper-picker),
> which uses **awww** instead — its wallpaper transitions keep playing even after
> the picker is closed, and it also supports animated (GIF) wallpapers. This
> repository is kept for reference.

## Usage

| Input | Action |
| --- | --- |
| `SUPER + W` | open / close the picker (toggles) |
| `←` / `→` | move the selection |
| mouse scroll | move the selection |
| `Enter` or click | apply the selected wallpaper |
| `Esc` | close |

It opens on the focused monitor, shows the current wallpaper blurred behind the
strip, and quits when closed (no background process).

## How it works

- **Launcher:** `scripts/open-picker.sh` (bound in your Hyprland config). If the
  picker is already running it closes it via IPC, otherwise it starts
  `qs -p ~/dev/projects/linux-rice`.
- **Scan + thumbnails:** `WallpaperModel.qml` runs `scripts/sync-thumbs.sh`,
  which lists `Config.wallpaperDir`, generates cached thumbnails (ImageMagick)
  and prints a manifest the model parses. Thumbnails live in
  `~/.cache/qs-wallpaper-picker/` and are rebuilt automatically.
- **UI:** `WallpaperPicker.qml` (the fullscreen layer window) + `WallpaperStrip.qml`
  (the coverflow). `BackdropBaker.qml` + `scripts/backdrop.sh` bake a blurred
  copy of the current wallpaper for the backdrop (screen-sized, so there is no
  edge fade and no scaling).
- **Apply:** `scripts/apply.sh` sets the wallpaper through hyprpaper's IPC and
  rewrites the `wallpaper {}` block in `hyprpaper.conf` so it is restored on
  login. The reveal transition plays in the picker's background.

## Configuration

Everything is in `Config.qml`:

- `wallpaperDir`, `extensions`.
- `thumbnails.mode` (`cover` / `preserve`), `width`, `height`, `cornerRadius`, `cacheDir`.
- `itemHeightRatio`, `visibleRange`.
- `coverflow.*` (`centerScale`, `edgeScale`, `falloffRange`, `spacingRatio`; set
  `enabled: false` for a flat strip).
- `backdrop` (`wallpaper` / `desktop`), `backgroundDim`, `backgroundBlur`,
  `topMargin`, `animationDuration`, `thumbnailFadeInDuration`.
- `closeOnApply`.
- `applyAnimation.type` (`none` / `circle` / `wipe`), `applyAnimation.duration`.
- `hyprpaperConf`, `fitMode`.

## Manual run

```bash
qs -p ~/dev/projects/linux-rice
```

## Requirements

Quickshell, ImageMagick (`magick`), hyprpaper, bash, and coreutils (`md5sum`).
