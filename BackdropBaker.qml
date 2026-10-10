import QtQuick
import Quickshell
import Quickshell.Io
import qs

/**
 * Generates (and caches) blurred, screen-sized backdrops on demand.
 *
 * Calls `ensure(source, callback)`; the callback receives the path of a cached
 * blurred image (or "" on failure). Requests are serialized, so several can be
 * queued at once (e.g. "old" and "new" for a transition).
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0

    required property string cacheDir
    property int blurRadius: 0
    property int outWidth: 2560
    property int outHeight: 1440

    readonly property string script: Quickshell.shellPath("scripts/backdrop.sh")

    property var _queue: []
    property var _current: null
    property string _result: ""

    function ensure(source, callback) {
        if (!source || source === "") {
            callback("");
            return;
        }
        root._queue.push({ source: source, cb: callback });
        root._pump();
    }

    function _pump() {
        if (root._current || root._queue.length === 0)
            return;
        root._current = root._queue.shift();
        // Guard against running before the window has a real size.
        if (root.outWidth < 8 || root.outHeight < 8) {
            const c = root._current;
            root._current = null;
            c.cb("");
            root._pump();
            return;
        }
        proc.command = [
            "bash", root.script,
            root._current.source,
            root.cacheDir,
            String(Math.max(1, root.outWidth)),
            String(Math.max(1, root.outHeight)),
            String(Math.max(0, root.blurRadius))
        ];
        root._result = "";
        proc.running = true;
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => { if (line !== "") root._result = line; }
        }
        onRunningChanged: {
            if (proc.running)
                return;
            const c = root._current;
            root._current = null;
            if (c)
                c.cb(root._result);
            root._result = "";
            root._pump();
        }
    }
}
