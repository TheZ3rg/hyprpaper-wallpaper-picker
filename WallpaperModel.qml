import QtQuick
import Quickshell
import Quickshell.Io
import qs

/**
 * Scans Config.wallpaperDir and exposes the wallpapers as `items`.
 *
 * The heavy lifting (finding files + generating cached thumbnails) is done by
 * scripts/sync-thumbs.sh, which prints a manifest the model parses. Items are
 * collected into a buffer and published once, so the strip is not rebuilt for
 * every single line.
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var items: []
    property bool scanning: false
    property bool ready: false
    property string error: ""

    signal loaded()

    readonly property string script: Quickshell.shellPath("scripts/sync-thumbs.sh")

    property var _buffer: []

    function rescan() {
        root._buffer = [];
        root.items = [];
        root.ready = false;
        root.error = "";
        root.scanning = true;
        proc.running = false;
        proc.running = true;
    }

    Process {
        id: proc
        command: [
            "bash", root.script,
            Config.wallpaperDir,
            Config.thumbnails.cacheDir,
            Config.thumbnails.mode,
            String(Config.thumbnails.width),
            String(Config.thumbnails.height),
            Config.extensions.join(","),
            String(Config.thumbnails.cornerRadius)
        ]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("\t");
                if (parts.length < 2 || parts[0] === "")
                    return;
                const w = parseFloat(parts[2]) || Config.thumbnails.width;
                const h = parseFloat(parts[3]) || Config.thumbnails.height;
                root._buffer.push({
                    path: parts[0],
                    source: "file://" + encodeURI(parts[0]),
                    thumb: "file://" + encodeURI(parts[1]),
                    aspect: (h > 0) ? (w / h) : 0.7
                });
            }
        }

        onStarted: root.scanning = true
        onRunningChanged: {
            if (!proc.running) {
                root.items = root._buffer;
                root.scanning = false;
                root.ready = true;
                root.loaded();
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.error = "scan failed (" + code + ")";
        }
    }

    Connections {
        target: Config
        function onWallpaperDirChanged() { root.rescan() }
    }

    Component.onCompleted: rescan()
}
