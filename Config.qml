pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Settings for the wallpaper picker.
 */
Singleton {
    id: root

    /// ---- Wallpapers ----
    /// The single folder that is scanned for wallpapers.
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    /// File extensions (lowercase, without the dot) that count as wallpapers.
    property var extensions: ["jpg", "jpeg", "png", "webp"]

    /// ---- Thumbnails ----
    property QtObject thumbnails: QtObject {
        /// "cover"    = crop to a fixed portrait ratio (best for coverflow)
        /// "preserve" = keep each image's own aspect ratio (letterboxed)
        property string mode: "cover"
        /// Narrow portrait strips (width / height ~= 0.35).
        property int width: 320
        property int height: 800
        /// Rounded corners baked into the thumbnail (0 = square/rectangular).
        property int cornerRadius: 0
        /// Auto-generated thumbnail cache (safe to delete; it is rebuilt).
        property string cacheDir: Quickshell.env("HOME") + "/.cache/qs-wallpaper-picker"
    }

    /// ---- Strip layout ----
    /// Height of the centred item, as a fraction of the screen height.
    property real itemHeightRatio: 0.34
    /// How many items are kept visible/loaded around the selection.
    property int visibleRange: 24

    /// ---- Coverflow ----
    property QtObject coverflow: QtObject {
        property bool enabled: true
        /// Scale of the centred item / of the items at the edges.
        property real centerScale: 1.2
        property real edgeScale: 0.42
        /// Distance (in item slots) over which the scale falls off.
        property real falloffRange: 9.0
        /// Gap between items, as a fraction of the base item height.
        property real spacingRatio: 0.02
    }

    /// ---- Look ----
    /// Backdrop behind the strip:
    ///   "wallpaper" = the current wallpaper, blurred and dimmed
    ///   "desktop"   = the live desktop/windows, blurred via ext-background-effect-v1
    property string backdrop: "wallpaper"
    /// Dim behind the strip (0..1).
    property real backgroundDim: 0.4
    /// Wallpaper-backdrop blur radius in px (0 = none).
    property real backgroundBlur: 48
    /// Top inset so the bar stays visible above the overlay (px).
    /// 0 = fullscreen; the bar is drawn above anyway (see Bar.qml layer).
    property real topMargin: 0
    /// Selection animation duration, ms.
    property int animationDuration: 500
    /// Fade-in duration for thumbnails as they finish decoding, ms (0 = instant).
    property int thumbnailFadeInDuration: 800

    /// ---- Behaviour ----
    /// Close the picker after applying a wallpaper. Set to false to keep it
    /// open (e.g. to try several wallpapers in a row).
    property bool closeOnApply: false

    /// ---- Wallpaper transition (played over the desktop when applying) ----
    property QtObject applyAnimation: QtObject {
        /// "none"   = no transition (instant)
        /// "circle" = the new wallpaper reveals from the centre outward
        /// "wipe"   = the new wallpaper reveals from the top downward
        property string type: "circle"
        /// Duration in milliseconds.
        property int duration: 800
    }

    /// ---- hyprpaper ----
    property string hyprpaperConf: Quickshell.env("HOME") + "/.config/hypr/hyprpaper.conf"
    /// fit_mode written to hyprpaper (cover / contain / tile / fill).
    property string fitMode: "cover"

    /// ---- Theming (deferred) ----
    /// When true, applying a wallpaper would also regenerate the Material You
    /// palette. Not wired up yet.
    property bool regenerateTheme: false
}
