import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

// Progress window for the conversion scripts (encode / remux / transcribe). Same chrome and the
// same 900x700 footprint as the report dialogs: theme background, 2px accent border, square
// corners, square buttons.
//
// qs-job starts the script with QS_JOB_STATUS pointing at a key=value status file and passes the
// window title along, because the title has to be right BEFORE the window maps: niri picks the
// window rule (and therefore the size) when it opens.
//
// Content, top to bottom: header, file name, VIDEO bar (percent + speed/ETA), FILES bar (units of a
// batch), and the LOG. The log is not decoration: these files are not always clean (TS/MTS, mp4
// with a broken header), ffmpeg keeps encoding anyway and drops something - audio, a stream - and
// that only shows up as a warning in the log. The scripts therefore no longer write their
// per-second "Progress: ..." line to stdout when stdout is not a terminal: the log keeps the
// headings, the ffmpeg warnings and the summary, and the bars carry the live numbers.
//
// The button is CANCEL while the job runs: it signals the script's process group (setsid makes its
// pid the group id) and the script's TERM trap deletes the partial output. Afterwards it is CLOSE.
//
// NOTE: keep every binding on a single line. A ternary split across lines ends the binding at the
// newline and the component then fails to instantiate (`createObject` returns null, no error in the
// log at all) - exactly how this file first failed to open.
FloatingWindow {
    id: root

    property string statusPath: ""
    property string initialTitle: ""

    readonly property Theme theme: Theme { }
    readonly property color secondaryText: "#bdae93"

    property string jobTitle: ""
    property string jobState: "running"
    // A script can die without writing a terminal state (an unguarded `set -e` abort, a segfault,
    // an OOM kill). The status file then stays `state=running` forever and the card would sit on
    // WORKING with a CANCEL chip that signals a process group that no longer exists. `pidGone` is
    // the pid-file probe, `orphaned` is the verdict once the probe says the process is gone.
    property bool pidGone: false
    property bool orphaned: false
    property string fileName: ""
    property int fileIndex: 0
    property int fileTotal: 0
    property real percent: 0
    property string speed: "-"
    property string eta: "--:--:--"
    property string message: ""
    property string logText: ""

    readonly property bool finished: root.orphaned || root.jobState === "cancelled" || (root.jobState === "done" && (root.fileTotal <= 0 || root.fileIndex >= root.fileTotal)) || (root.jobState === "failed" && root.fileTotal > 0 && root.fileIndex >= root.fileTotal)
    readonly property bool showUnits: root.fileTotal > 1
    readonly property real doneUnits: root.finished ? root.fileTotal : Math.max(0, root.fileIndex - 1)
    readonly property real unitPercent: root.fileTotal > 0 ? Math.max(0, Math.min(100, root.doneUnits / root.fileTotal * 100)) : 0
    readonly property color stateColor: (root.orphaned || root.jobState === "failed") ? root.theme.warning : root.jobState === "cancelled" ? root.secondaryText : root.jobState === "done" ? root.theme.success : root.theme.accent
    readonly property string stateLabel: (root.orphaned || root.jobState === "failed") ? "FAILED" : root.jobState === "done" ? "DONE" : root.jobState === "cancelled" ? "CANCELLED" : "WORKING"
    readonly property string statusLine: root.jobState === "running" && !root.orphaned && root.message === "" ? ("SPEED " + root.speed + "   ETA " + root.eta) : root.message

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: root.theme.panel
    title: (root.jobTitle !== "" ? root.jobTitle : root.initialTitle !== "" ? root.initialTitle : "Job") + (root.fileName !== "" ? " · " + root.fileName : "")
    visible: true
    width: 900
    height: 700
    implicitWidth: 900
    implicitHeight: 700

    function applyStatus(text) {
        const fields = {};
        for (const line of text.split("\n")) {
            const at = line.indexOf("=");
            if (at > 0)
                fields[line.slice(0, at).trim()] = line.slice(at + 1).trim();
        }
        if (fields.title !== undefined) root.jobTitle = fields.title;
        if (fields.state !== undefined) root.jobState = fields.state;
        if (fields.file !== undefined) root.fileName = fields.file;
        if (fields.index !== undefined) root.fileIndex = parseInt(fields.index) || 0;
        if (fields.total !== undefined) root.fileTotal = parseInt(fields.total) || 0;
        if (fields.percent !== undefined) root.percent = Math.max(0, Math.min(100, parseFloat(fields.percent) || 0));
        if (fields.speed !== undefined) root.speed = fields.speed;
        if (fields.eta !== undefined) root.eta = fields.eta;
        if (fields.message !== undefined) root.message = fields.message;
    }

    // The shell owns this object: it keeps one window per status path and drops it from that map
    // when the card closes, so a dead window never blocks the same job from showing again.
    signal closeRequested()

    function closeWindow() {
        root.visible = false;
        root.closeRequested();
    }

    // Closing through the compositor (Mod+X, or a niri action) must take the same path, otherwise
    // the shell keeps a window it believes is still on screen.
    onClosed: root.closeRequested()

    function cancelJob() {
        if (root.finished) {
            root.closeWindow();
            return;
        }
        // Nothing left to signal: the script is already gone. Dismiss the card instead of leaving a
        // CANCEL chip that can never do anything (the old behaviour: kill on a dead pid silently
        // failed, the message stayed "Cancelling...", and the window was stuck on screen forever).
        if (root.pidGone) {
            root.orphaned = true;
            root.message = root.message === "" ? "process exited without a final status - see log" : root.message;
            return;
        }
        // TERM the whole group (setsid makes the script pid the group id), then escalate to KILL if it
        // is still alive after ~5 s: a job that ignores TERM must not leave an unclosable card behind.
        cancelProc.command = ["sh", "-c", 'p=$(cat "$1" 2>/dev/null) || exit 0; [ -n "$p" ] || exit 0; kill -TERM -"$p" 2>/dev/null; i=0; while [ "$i" -lt 20 ] && kill -0 "$p" 2>/dev/null; do sleep 0.25; i=$((i+1)); done; kill -0 "$p" 2>/dev/null && kill -KILL -"$p" 2>/dev/null; exit 0', "sh", root.statusPath + ".pid"];
        cancelProc.running = true;
        root.message = "Cancelling...";
    }

    Timer {
        interval: 400
        repeat: true
        running: !root.finished
        triggeredOnStart: true
        onTriggered: {
            if (root.statusPath === "")
                return;
            statusProc.running = true;
            logProc.running = true;
            pidProc.running = true;
        }
    }

    // Liveness probe for the script itself. Exit 0 = alive, 3 = no pid file yet (not a verdict),
    // 4 = the pid in the file is gone. A gone pid is a suspicion, not a result: the script may have
    // written its terminal frame milliseconds before exiting, so the fresh status read gets a moment
    // to land before the card is declared orphaned.
    Process {
        id: pidProc
        command: ["sh", "-c", 'p=$(cat "$1" 2>/dev/null); [ -n "$p" ] || exit 3; kill -0 "$p" 2>/dev/null || exit 4', "sh", root.statusPath + ".pid"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.pidGone = false;
            } else if (exitCode === 4 && !root.finished) {
                root.pidGone = true;
                if (!orphanWatch.running)
                    orphanWatch.start();
            }
        }
    }

    Timer {
        id: orphanWatch
        interval: 1600
        repeat: false
        onTriggered: {
            if (!root.finished) {
                root.orphaned = true;
                root.message = root.message === "" ? "process exited without a final status - see log" : root.message;
            }
        }
    }

    // The summary is the reason the log gets read at all: the totals and the space saved. The poll
    // timer stops on the same tick that flips `finished`, so the last read can land a hair before
    // the summary lines are written and leave them below the visible area with nothing left to
    // scroll them in. A finished job therefore takes one more read.
    onFinishedChanged: {
        if (root.finished)
            logProc.running = true;
    }

    Process {
        id: statusProc
        command: ["cat", root.statusPath]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.applyStatus(text)
        }
    }

    Process {
        id: logProc
        command: ["sh", "-c", 'tail -n 400 "$1" 2>/dev/null', "sh", root.statusPath + ".log"]
        stdout: StdioCollector {
            onStreamFinished: root.logText = String(text || "").replace(/[ \t]+$/gm, "")
        }
    }

    Process {
        id: copier
        command: ["sh", "-c", 'wl-copy < "$1" 2>/dev/null || true', "sh", root.statusPath + ".log"]
    }

    Process {
        id: cancelProc
        command: ["true"]
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.cancelJob()
    }

    // ---------------------------------------------------------------- surface

    Rectangle {
        anchors.fill: parent
        color: root.theme.panel
        border.width: 2
        border.color: root.theme.accent
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.title
                    color: root.theme.fg
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 2
                    font.weight: Font.Bold
                }

                Text {
                    text: root.stateLabel
                    color: root.stateColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 1
                    font.weight: Font.DemiBold
                }

                // COPY: the whole log, not just what is scrolled into view - it is what gets
                // pasted into an AI when ffmpeg warned about a broken header mid-run.
                Rectangle {
                    Layout.preferredWidth: 74
                    Layout.preferredHeight: 28
                    color: copyHover.hovered ? root.theme.accent : "transparent"
                    border.width: 1
                    border.color: root.secondaryText

                    Text {
                        anchors.centerIn: parent
                        text: "COPY"
                        color: root.theme.fg
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize - 1
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: copyHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: copier.running = true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 28
                    color: hover.hovered ? root.theme.accent : "transparent"
                    border.width: 1
                    border.color: root.secondaryText

                    Text {
                        anchors.centerIn: parent
                        text: root.finished ? "CLOSE" : "CANCEL"
                        color: root.theme.fg
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize - 1
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.cancelJob()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: root.fileName !== "" ? root.fileName : "waiting for the first status..."
                color: root.secondaryText
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize
            }

            // ---------------------------------------------------------------- video bar

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "VIDEO"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 2
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    text: root.percent.toFixed(1) + "%"
                    color: root.stateColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.statusLine
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                color: Qt.rgba(root.theme.fg.r, root.theme.fg.g, root.theme.fg.b, 0.08)

                Rectangle {
                    width: parent.width * (root.percent / 100)
                    height: parent.height
                    color: root.stateColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // ---------------------------------------------------------------- unit bar

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                visible: root.showUnits
                spacing: 10

                Text {
                    text: "FILES"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 2
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    text: root.unitPercent.toFixed(1) + "%"
                    color: root.theme.fg
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Math.min(root.fileTotal, root.doneUnits) + " / " + root.fileTotal + " files"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                visible: root.showUnits
                color: Qt.rgba(root.theme.fg.r, root.theme.fg.g, root.theme.fg.b, 0.08)

                Rectangle {
                    width: parent.width * (root.unitPercent / 100)
                    height: parent.height
                    color: root.theme.fg

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // ---------------------------------------------------------------- log

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "LOG"
                color: root.secondaryText
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize - 2
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(root.theme.fg.r, root.theme.fg.g, root.theme.fg.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(root.theme.fg.r, root.theme.fg.g, root.theme.fg.b, 0.08)

                Flickable {
                    id: logScroll
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: width
                    contentHeight: logBody.height
                    boundsBehavior: Flickable.StopAtBounds

                    // Follow the tail while the user has not scrolled up.
                    property bool follow: true
                    onContentYChanged: follow = contentY + height >= contentHeight - 12

                    TextEdit {
                        id: logBody
                        width: logScroll.width
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.WrapAnywhere
                        text: root.logText !== "" ? root.logText : "no output yet"
                        color: root.secondaryText
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize - 3
                        selectionColor: Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.35)
                        selectedTextColor: root.theme.fg
                        cursorVisible: false
                    }

                    onContentHeightChanged: if (follow || root.finished) contentY = Math.max(0, contentHeight - height)
                    Component.onCompleted: contentY = Math.max(0, contentHeight - height)

                    Connections {
                        target: root

                        function onLogTextChanged() {
                            if (logScroll.follow || root.finished)
                                logScroll.contentY = Math.max(0, logScroll.contentHeight - logScroll.height);
                        }
                    }
                }
            }
        }
    }
}
