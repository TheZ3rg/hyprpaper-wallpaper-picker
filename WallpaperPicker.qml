import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

/**
 * Fullscreen wallpaper picker overlay on the focused monitor.
 * Standalone Quickshell config: launched with `qs -p`, quits when closed.
 *
 * Drawn on the "top" layer (the bar sits on "overlay", above it). Backdrop
 * modes (Config.backdrop):
 *   "wallpaper" - a cached, screen-sized blurred copy of the current wallpaper
 *                 (baked with ImageMagick so it is 1:1 with no edge fade)
 *   "desktop"   - the live desktop/windows, blurred via ext-background-effect-v1
 *
 * Applying a wallpaper plays a transition in the picker's background: the new
 * wallpaper (also baked/blurred) reveals over the old one, from the centre
 * (circle) or from the top (wipe). Configured by Config.applyAnimation.
 */
PanelWindow {
    id: root

    visible: true
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:wallpaperPicker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    margins.top: Config.topMargin

    readonly property string applyScript: Quickshell.shellPath("scripts/apply.sh")

    /// The wallpaper currently set in hyprpaper.
    readonly property string currentPath: {
        hyprpaperFile.rev; // re-evaluate when the file changes
        const m = hyprpaperFile.text().match(/^[ \t]*path[ \t]*=[ \t]*(.+?)[ \t]*$/m);
        return m ? m[1] : "";
    }
    readonly property url currentWallpaper:
        root.currentPath !== "" ? ("file://" + encodeURI(root.currentPath)) : ""

    FileView {
        id: hyprpaperFile
        path: Config.hyprpaperConf
        watchChanges: true
        property int rev: 0
        onLoadedChanged: hyprpaperFile.rev++
        onFileChanged: {
            hyprpaperFile.reload();
            hyprpaperFile.rev++;
        }
    }

    WallpaperModel {
        id: model
    }

    BackdropBaker {
        id: baker
        cacheDir: Config.thumbnails.cacheDir
        blurRadius: Config.backgroundBlur
        outWidth: root.width
        outHeight: root.height
    }

    Region {
        id: desktopBlurRegion
        item: root.contentItem
    }
    BackgroundEffect.blurRegion: Config.backdrop === "desktop" ? desktopBlurRegion : null

    // ---- Steady backdrop (baked blurred current wallpaper) ----
    property string steadyBackdrop: ""

    function refreshSteadyBackdrop() {
        if (root.currentPath === "" || root.width < 200 || root.height < 200) {
            root.steadyBackdrop = "";
            return;
        }
        const src = root.currentPath;
        baker.ensure(src, function(p) {
            if (src === root.currentPath) // ignore stale results
                root.steadyBackdrop = p;
        });
    }

    Component.onCompleted: refreshSteadyBackdrop()
    onCurrentPathChanged: refreshSteadyBackdrop()
    onWidthChanged: refreshSteadyBackdrop()
    onHeightChanged: refreshSteadyBackdrop()
    Connections {
        target: Config
        function onBackgroundBlurChanged() { root.refreshSteadyBackdrop(); }
    }

    // ---- Apply transition state ----
    readonly property bool transitionEnabled: Config.applyAnimation.type !== "none"
    property bool transitioning: false
    property url transFromUrl: ""
    property url transToUrl: ""
    property real transitionProgress: 0

    property string _fromPath: ""
    property string _toPath: ""
    property string _fromBaked: ""
    property string _toBaked: ""
    property int _bakedCount: 0
    property bool _transitionPending: false

    NumberAnimation {
        id: transitionAnim
        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: Math.max(1, Config.applyAnimation.duration)
        easing.type: Easing.InOutSine
        onFinished: {
            if (Config.closeOnApply)
                Qt.quit();
            else
                root.transitioning = false;
        }
    }

    // ---- Visual content ----
    Item {
        id: contentRoot
        anchors.fill: parent

        // Normal backdrop
        Item {
            id: normalBackdrop
            anchors.fill: parent
            visible: !root.transitioning

            // Baked blurred current wallpaper (1:1, no zoom, no edge fade)
            Image {
                id: bakedBackdrop
                anchors.fill: parent
                source: (Config.backdrop === "wallpaper" && root.steadyBackdrop !== "")
                    ? ("file://" + root.steadyBackdrop) : ""
                fillMode: Image.PreserveAspectCrop
                cache: true
            }

            // Fallback while the baked image is being generated (or for the
            // "live" look): runtime blur of the actual wallpaper.
            Item {
                anchors.fill: parent
                visible: Config.backdrop === "wallpaper" && bakedBackdrop.status !== Image.Ready

                Image {
                    id: bgImage
                    anchors.fill: parent
                    source: root.currentWallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bgImage
                    visible: Config.backgroundBlur > 0 && bgImage.status === Image.Ready
                    blurEnabled: true
                    blurMax: Math.max(1, Config.backgroundBlur)
                    blur: 1
                }
                Image {
                    anchors.fill: parent
                    source: root.currentWallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: Config.backgroundBlur <= 0 && status === Image.Ready
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, Config.backgroundDim)
            }
        }

        // Transition backdrop — both wallpapers are baked/blurred, so the
        // reveal stays 1:1 with full blur.
        Item {
            id: transitionBackdrop
            anchors.fill: parent
            visible: root.transitioning

            Image {
                id: transFrom
                anchors.fill: parent
                source: root.transFromUrl
                fillMode: Image.PreserveAspectCrop
                cache: true
            }
            Image {
                id: transTo
                anchors.fill: parent
                source: root.transToUrl
                fillMode: Image.PreserveAspectCrop
                visible: false
                // Keep the layer on permanently: toggling it makes MultiEffect
                // reuse a stale source texture on the next transition.
                layer.enabled: true
            }
            Item {
                id: transMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                readonly property bool circle: Config.applyAnimation.type === "circle"
                readonly property real maxRadius:
                    Math.sqrt(Math.pow(root.width / 2, 2) + Math.pow(root.height / 2, 2))
                readonly property real circleSize: root.transitionProgress * 2 * maxRadius

                Rectangle {
                    id: transShape
                    color: "white"
                    width: transMask.circle ? transMask.circleSize : transMask.width
                    height: transMask.circle ? transMask.circleSize
                                              : root.transitionProgress * transMask.height
                    radius: transMask.circle ? transMask.circleSize / 2 : 0
                    x: transMask.circle ? (transMask.width - transMask.circleSize) / 2 : 0
                    y: transMask.circle ? (transMask.height - transMask.circleSize) / 2 : 0
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: transTo
                maskEnabled: true
                maskSource: transMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, Config.backgroundDim)
            }
        }

        // The strip (always visible, above the backdrop)
        WallpaperStrip {
            id: strip
            anchors.fill: parent
            items: model.items
            onActivated: index => root.applyIndex(index)
        }
    }

    // Centre the picker on the currently applied wallpaper once loaded.
    Connections {
        target: model
        function onLoaded() {
            const i = model.items.findIndex(it => it.path === root.currentPath);
            if (i >= 0)
                strip.currentIndex = i;
        }
    }

    function applyIndex(index) {
        const it = model.items[index];
        if (!it)
            return;

        // Picking the wallpaper that is already set does nothing.
        if (it.path === root.currentPath)
            return;

        if (!root.transitionEnabled) {
            Quickshell.execDetached(["bash", root.applyScript, it.path, Config.fitMode, Config.hyprpaperConf]);
            if (Config.closeOnApply)
                Qt.quit();
            return;
        }

        // Bake (blurred) copies of the old and new wallpaper, then reveal.
        root._fromPath = root.currentPath;
        root._toPath = it.path;
        root._fromBaked = "";
        root._toBaked = "";
        root._bakedCount = 0;
        root._transitionPending = true;
        baker.ensure(root._fromPath, function(p) { root._fromBaked = p; root._onBaked(); });
        baker.ensure(root._toPath,   function(p) { root._toBaked   = p; root._onBaked(); });
        transitionPrepTimer.restart();
    }

    function _onBaked() {
        root._bakedCount++;
        if (root._transitionPending && root._bakedCount >= 2)
            root._beginTransition(false);
    }

    function _beginTransition(force) {
        if (!root._transitionPending)
            return;
        if (!force && root._bakedCount < 2)
            return;

        root._transitionPending = false;
        transitionPrepTimer.stop();

        root.transFromUrl = root._fromBaked !== ""
            ? ("file://" + root._fromBaked)
            : (root._fromPath !== "" ? ("file://" + encodeURI(root._fromPath)) : "");
        root.transToUrl = root._toBaked !== ""
            ? ("file://" + root._toBaked)
            : ("file://" + encodeURI(root._toPath));

        root.transitionProgress = 0;
        root.transitioning = true;

        Quickshell.execDetached(["bash", root.applyScript, root._toPath, Config.fitMode, Config.hyprpaperConf]);
        transitionAnim.restart();
    }

    // Forces the transition if baking/loading somehow never completes.
    Timer {
        id: transitionPrepTimer
        interval: 2000
        onTriggered: root._beginTransition(true)
    }

    // ---- Keyboard ----
    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: strip.prev()
    }
    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: strip.next()
    }
    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut
        enabled: model.ready
        onActivated: root.applyIndex(strip.currentIndex)
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    IpcHandler {
        target: "wallpaperPicker"

        function close(): void { Qt.quit(); }
        function toggle(): void { Qt.quit(); }
    }
}
