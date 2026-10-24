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
    property string fileName: ""
    property int fileIndex: 0
    property int fileTotal: 0
    property real percent: 0
    property string speed: "-"
    property string eta: "--:--:--"
    property string message: ""
    property string logText: ""

    readonly property bool finished: root.jobState === "cancelled" || (root.jobState === "done" && (root.fileTotal <= 0 || root.fileIndex >= root.fileTotal)) || (root.jobState === "failed" && root.fileTotal > 0 && root.fileIndex >= root.fileTotal)
    readonly property bool showUnits: root.fileTotal > 1
    readonly property real doneUnits: root.finished ? root.fileTotal : Math.max(0, root.fileIndex - 1)
    readonly property real unitPercent: root.fileTotal > 0 ? Math.max(0, Math.min(100, root.doneUnits / root.fileTotal * 100)) : 0
    readonly property color stateColor: root.jobState === "failed" ? root.theme.warning : root.jobState === "cancelled" ? root.secondaryText : root.jobState === "done" ? root.theme.success : root.theme.accent
    readonly property string stateLabel: root.jobState === "done" ? "DONE" : root.jobState === "failed" ? "FAILED" : root.jobState === "cancelled" ? "CANCELLED" : "WORKING"

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: root.theme.panel
    title: root.jobTitle !== "" ? root.jobTitle : root.initialTitle !== "" ? root.initialTitle : "Job"
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

    function closeWindow() {
        root.visible = false;
    }

    function cancelJob() {
        if (root.finished) {
            root.closeWindow();
            return;
        }
        cancelProc.command = ["sh", "-c", 'p=$(cat "$1" 2>/dev/null); [ -n "$p" ] && kill -TERM -"$p" 2>/dev/null; exit 0', "sh", root.statusPath + ".pid"];
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
                    text: root.jobState === "running" ? ("SPEED " + root.speed + "   ETA " + root.eta) : root.message
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
