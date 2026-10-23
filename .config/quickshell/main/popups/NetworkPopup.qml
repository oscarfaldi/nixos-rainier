import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../theme"

PanelWindow {
    id: root

    // Opened state, driven by the bar module (was the window's own `visible`).
    property bool open: false

    readonly property Theme theme: Theme {}

    // Gruvbox light4. Easier to read than the very dark muted color.
    readonly property color secondaryText: "#bdae93"

    property var selectedDevice: null
    property var profileMap: ({})

    property string detailState: ""
    property string detailConnection: ""
    property string detailIp: ""
    property string detailGateway: ""
    property string detailError: ""

    property bool editorOpen: false
    property Item editorAnchor: null
    property string editorProfile: ""
    property string editorInterface: ""
    property bool editorWasConnected: false

    property bool errorVisible: false
    property string errorText: ""

    // Speed test state. The probe script prints one Mbps sample per second; the result shown is
    // the average of the samples after the first one (the first second is warm-up).
    property bool speedRunning: false
    property string speedDirection: ""
    property real speedLive: 0
    property real speedLastDown: 0
    property real speedLastUp: 0
    property var speedSamples: []

    // One press measures BOTH directions: download first, upload second, like a dashboard dial
    // pair. `speedBoth` is what carries the run from one leg to the next.
    property bool speedBoth: false

    // Full scale of the dials: the owner's line is 1 Gbps, so 1000 Mbps makes the needle read as
    // "how much of the link am I actually getting".
    readonly property real speedScale: 1000

    readonly property string speedStatusText: {
        if (root.speedLastDown <= 0 && root.speedLastUp <= 0)
            return "never measured - press the dial"

        return "last: " + root.speedLastDown.toFixed(0) + " down · "
            + root.speedLastUp.toFixed(0) + " up Mbps"
    }

    // Fast.com (Netflix OCA) targets, i.e. it measures the link against the owner's own ISP cache
    // - on MyRepublic Indonesia that is a local node, so the number is the real line rate.
    function runSpeedTest(direction) {
        if (root.speedRunning)
            return

        root.speedBoth = direction === "both"
        root.speedRunning = true
        root.errorVisible = false
        root.speedSamples = []
        root.speedLive = 0
        root.startSpeedPhase(root.speedBoth ? "down" : direction)
    }

    function startSpeedPhase(direction) {
        root.speedDirection = direction
        root.speedSamples = []
        root.speedLive = 0

        speedProcess.running = false
        speedProcess.command = [
            "sh",
            Quickshell.env("HOME") + "/System/.config/quickshell/scripts/speedtest.sh",
            direction,
            "8"
        ]
        speedProcess.running = true
    }

    function finishSpeedTest(code) {
        const samples = root.speedSamples || []
        // The first second is warm-up: the workers are still opening connections.
        const measured = samples.length > 1 ? samples.slice(1) : samples
        let sum = 0

        for (let i = 0; i < measured.length; ++i)
            sum += measured[i]

        const average = measured.length > 0 ? sum / measured.length : 0

        if (code === 0 && average > 0) {
            if (root.speedDirection === "up")
                root.speedLastUp = average
            else
                root.speedLastDown = average
        }

        // Download finished: carry on with the upload leg of the same press.
        if (root.speedBoth && root.speedDirection === "down" && code === 0) {
            root.startSpeedPhase("up")
            return
        }

        root.speedLive = 0
        root.speedRunning = false
        root.speedBoth = false
    }

    readonly property var devices: Networking.devices.values

    readonly property bool hasWifi:
        root.devices.some(
            device => device.type === DeviceType.Wifi
        )

    width: 500
    // 850: connection list + the taller WARP row + details + the two speed dials. A fixed height
    // that is too small slices the bottom row instead of scrolling.
    height: 850

    // No input grab (plain layer surface): bar clicks keep working while
    // the popup is open. Fixed top-right position, flush with the bar's
    // right edge, 12px below the bar (owner-approved values).
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.right: true
    // niri positions layer margins from the SCREEN edge, not from the
    // free area: 48 (bar zone) + 13 (bar margin) + 35 (bar height) + 12
    // (gap) keeps the panel below the bar without covering it.
    margins.top: root.theme.popupTop
    margins.right: root.theme.margins

    color: "transparent"

    // Keyboard focus while open so Escape can reach this surface (see PopupKeys at the bottom).
    // The embedded editor's text fields get their focus by being clicked, which is unaffected.
  // Pre-mapped: the surface stays mapped and only opacity / input region / keyboard focus change,
  // so opening costs no surface creation (~180 ms measured on demand). An empty mask means zero
  // input while closed: the pointer behaves exactly like an unmapped panel.
  visible: true

  mask: Region {
    item: root.open ? frame : null
  }

    WlrLayershell.keyboardFocus:
        root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    // --------------------------------------------------
    // SPEED TEST PROCESS
    // --------------------------------------------------

    Process {
        id: speedProcess

        stdout: SplitParser {
            onRead: (line) => {
                const value = Number(String(line).trim())

                if (!Number.isFinite(value))
                    return

                root.speedLive = value
                root.speedSamples = root.speedSamples.concat([value])
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim()

                if (message !== "") {
                    root.errorText = message
                    root.errorVisible = true
                }
            }
        }

        onExited: (code) => root.finishSpeedTest(code)
    }

    // --------------------------------------------------
    // PROFILE LOOKUP
    // --------------------------------------------------

    function refreshProfiles() {
        profileProcess.running = false
        profileProcess.command = [
            "nmcli",
            "-t",
            "-f",
            "NAME,DEVICE",
            "connection",
            "show"
        ]
        profileProcess.running = true
    }

    function profileFor(device) {
        if (!device)
            return null

        return root.profileMap[device.name] || null
    }

    function connectionName(device) {
        const profile = root.profileFor(device)

        if (profile)
            return profile

        const network = root.networkFor(device)

        if (network && network.name)
            return network.name

        return "No connection"
    }

    function networkFor(device) {
        if (!device)
            return null

        if (device.type === DeviceType.Wired)
            return device.network

        const networks =
            device.networks
                ? device.networks.values
                : []

        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i]
        }

        return null
    }

    // --------------------------------------------------
    // DEVICE INFO
    // --------------------------------------------------

    function speedLabel(device) {
        if (
            !device ||
            device.type !== DeviceType.Wired ||
            !device.linkSpeed
        )
            return ""

        return device.linkSpeed >= 1000
            ? (device.linkSpeed / 1000).toFixed(0) + " Gbps"
            : device.linkSpeed + " Mbps"
    }

    function stateLabel(device) {
        if (!device)
            return "Unknown"

        if (device.connected)
            return "Connected"

        if (
            device.type === DeviceType.Wired &&
            !device.hasLink
        )
            return "No link"

        return "Disconnected"
    }

    function selectDevice(device) {
        root.selectedDevice = device
        root.detailError = ""
        root.refreshDetails()
    }

    // --------------------------------------------------
    // DETAILS
    // --------------------------------------------------

    function refreshDetails() {
        if (!root.selectedDevice)
            return

        detailsProcess.running = false
        detailsProcess.command = [
            "nmcli",
            "-t",
            "-f",
            "GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY",
            "device",
            "show",
            root.selectedDevice.name
        ]
        detailsProcess.running = true
    }

    function parseDetails(text) {
        const lines =
            text
                .replace(/\r/g, "")
                .split("\n")

        root.detailState = ""
        root.detailConnection = ""
        root.detailIp = ""
        root.detailGateway = ""

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const colon = line.indexOf(":")

            if (colon < 0)
                continue

            const key = line.substring(0, colon)
            const value = line.substring(colon + 1)

            if (key === "GENERAL.STATE")
                root.detailState = value

            else if (key === "GENERAL.CONNECTION")
                root.detailConnection = value

            else if (key.startsWith("IP4.ADDRESS"))
                root.detailIp = value

            else if (key === "IP4.GATEWAY")
                root.detailGateway = value

        }

    }

    // --------------------------------------------------
    // CONNECT / DISCONNECT
    // --------------------------------------------------

    function toggleDevice(device) {
        if (!device)
            return

        actionProcess.running = false

        if (device.connected) {
            actionProcess.command = [
                "nmcli",
                "device",
                "disconnect",
                device.name
            ]
        } else {
            const profile = root.profileFor(device)

            if (profile) {
                actionProcess.command = [
                    "nmcli",
                    "connection",
                    "up",
                    "id",
                    profile,
                    "ifname",
                    device.name
                ]
            } else {
                actionProcess.command = [
                    "nmcli",
                    "device",
                    "connect",
                    device.name
                ]
            }
        }

        actionProcess.running = true
    }

    // --------------------------------------------------
    // EDIT
    // --------------------------------------------------

    function openEditor(device, button) {
        const profile = root.profileFor(device)

        if (!profile)
            return

        root.editorProfile = profile
        root.editorInterface = device.name
        root.editorWasConnected = device.connected
        root.editorAnchor = button
        root.editorOpen = true
    }

    // --------------------------------------------------
    // WARP
    // --------------------------------------------------

    property string warpStatus: "Checking"
    property bool warpBusy: false
    // State we asked the daemon for ("On" / "Off"). Polling stops as soon as status matches it,
    // so a stale reading right after the command cannot end the wait early.
    property string warpExpected: ""
    // Remaining status checks while the daemon settles (~8 s at 700 ms).
    property int warpPollsLeft: 0
    // Extra steps queued after the current command exits.
    property var warpQueue: []

    function warpRefresh() {
        warpStatusProcess.running = false
        warpStatusProcess.command = [ "warp-cli", "--accept-tos", "status" ]
        warpStatusProcess.running = true
    }

    function warpRun(args) {
        warpActionProcess.running = false
        warpActionProcess.command = [ "warp-cli", "--accept-tos", ...args ]
        warpActionProcess.running = true
    }

    function warpToggle() {
        if (root.warpBusy)
            return

        root.warpQueue = []
        root.warpBusy = true

        if (root.warpStatus === "On") {
            root.warpExpected = "Off"
            root.warpRun([ "disconnect" ])
        } else if (root.warpStatus === "Not registered") {
            // One click on a fresh install: register, then connect right after it succeeds.
            root.warpExpected = "On"
            root.warpQueue.push("connect")
            root.warpRun([ "registration", "new" ])
        } else {
            root.warpExpected = "On"
            root.warpRun([ "connect" ])
        }
    }

    // Ask the daemon over and over until it reports the state we asked for.
    //
    // `warp-cli status` run a few milliseconds after `connect` still prints "Disconnected" - the
    // tunnel comes up a moment later. Trusting that first reading (and only following the word
    // "Connecting") made the chip drop back to OFF while the tunnel was already coming up, so the
    // toggle appeared to need a second click to work.
    function warpSettle() {
        root.warpPollsLeft = 12
        warpPollTimer.stop()
        root.warpRefresh()
    }

    Timer {
        id: warpPollTimer

        interval: 700
        repeat: false
        running: false

        onTriggered: root.warpRefresh()
    }

    Process {
        id: warpStatusProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text

                // NOTE: "Disconnected" contains the substring "connected",
                // so it MUST be classified before the Connected check.
                if (/Registration Missing|Unable/i.test(text))
                    root.warpStatus = "Not registered"
                else if (/Connecting/i.test(text))
                    root.warpStatus = "Connecting"
                else if (/Disconnected/i.test(text))
                    root.warpStatus = "Off"
                else if (/Connected/i.test(text))
                    root.warpStatus = "On"
                else
                    root.warpStatus = "Off"


                if (root.warpPollsLeft > 0) {
                    root.warpPollsLeft = root.warpPollsLeft - 1

                    const settled = root.warpExpected === ""
                        || root.warpStatus === root.warpExpected

                    if (!settled && root.warpPollsLeft > 0) {
                        warpPollTimer.restart()
                    } else {
                        root.warpPollsLeft = 0
                        root.warpExpected = ""
                        root.warpBusy = false
                    }
                } else {
                    root.warpBusy = false
                }
            }
        }
    }

    Process {
        id: warpActionProcess

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.showError(this.text)
            }
        }

        onExited: (code) => {
            if (root.warpQueue.length > 0) {
                root.warpQueue.shift()
                root.warpRun([ "connect" ])
                return
            }

            // Chain finished: poll until the daemon agrees (busy stays on meanwhile).
            root.warpSettle()
        }
    }

    // --------------------------------------------------
    // ERROR TOAST
    // --------------------------------------------------

    function showError(message) {
        const clean =
            String(message || "")
                .replace(/\r?\n+/g, " · ")
                .trim()

        root.errorText =
            clean || "Network action failed."

        root.errorVisible = true
        errorTimer.restart()
    }

    Timer {
        id: errorTimer

        interval: 3500
        repeat: false

        onTriggered: {
            root.errorVisible = false
        }
    }

    // --------------------------------------------------
    // PROCESSES
    // --------------------------------------------------

    Process {
        id: profileProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                const lines =
                    this.text
                        .replace(/\r/g, "")
                        .split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    const parts = line.split(":")

                    if (parts.length < 2)
                        continue

                    const name = parts[0]
                    const device = parts.slice(1).join(":")

                    if (
                        name &&
                        device &&
                        device !== "--"
                    )
                        map[device] = name
                }

                root.profileMap = map
            }
        }

        onExited: {
            root.refreshDetails()
        }
    }

    Process {
        id: detailsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseDetails(this.text)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.showError(this.text)
            }
        }

        onExited: (code) => {
            if (
                code !== 0 &&
                !root.detailError
            )
                root.showError(
                    "Unable to read network details."
                )
        }
    }

    Process {
        id: actionProcess

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.showError(this.text)
            }
        }

        onExited: (code) => {
            if (code !== 0 && !root.errorVisible) {
                root.showError(
                    "Network action failed."
                )
                return
            }

            root.refreshProfiles()
            root.refreshDetails()
        }
    }

    // --------------------------------------------------
    // MAIN CONTAINER
    // --------------------------------------------------

    Rectangle {

      id: frame
        opacity: root.open ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: root.theme.duration(root.theme.motion)
            easing.type: Easing.OutCubic
          }
        }


        anchors.fill: parent

        color: root.theme.panel

        border.width: 2
        border.color: root.theme.accent

        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // ==================================================
            // HEADER
            // ==================================================

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "󰈀  NETWORK"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize + 3
                    font.weight: Font.Bold

                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.hasWifi

                    width: 82
                    height: 28

                    color:
                        Networking.wifiEnabled
                            ? root.theme.accent
                            : "transparent"

                    border.width: 1
                    border.color: root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text:
                            Networking.wifiEnabled
                                ? "WI-FI ON"
                                : "WI-FI OFF"

                        color: root.theme.fg

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize - 2
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            Networking.wifiEnabled =
                                !Networking.wifiEnabled
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            // ==================================================
            // CONNECTIONS
            // ==================================================

            Text {
                text: "CONNECTIONS"

                color: root.theme.accent

                font.family: root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize + 2
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.18
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: 216

                spacing: 6
                clip: true

                model: ScriptModel {
                    values: root.devices
                }

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    width: list.width
                    height: 66

                    color: "transparent"

                    border.width:
                        modelData === root.selectedDevice
                            ? 2
                            : 1

                    border.color:
                        modelData === root.selectedDevice
                            ? root.theme.accent
                            : root.secondaryText

                    // Active / hover surface
                    Rectangle {
                        anchors.fill: parent

                        color: root.theme.accent

                        opacity:
                            modelData === root.selectedDevice
                                ? 0.12
                                : hoverHandler.hovered
                                    ? 0.08
                                    : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        spacing: 10

                        Text {
                            text:
                                modelData.type ===
                                DeviceType.Wired
                                    ? "󰈀"
                                    : "󰖩"

                            color: root.theme.fg

                            font.family:
                                root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize + 2
                            font.weight: Font.Bold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing: 1

                            Text {
                                text:
                                    root.connectionName(
                                        modelData
                                    )

                                color: root.theme.fg

                                font.family:
                                    root.theme.fontFamily
                                font.pixelSize:
                                    root.theme.fontSize + 1
                                font.weight: Font.Bold

                                elide:
                                    Text.ElideRight

                                Layout.fillWidth: true
                            }

                            Text {
                                text:
                                    modelData.name +
                                    "  ·  " +
                                    root.stateLabel(
                                        modelData
                                    )

                                color: root.secondaryText

                                font.family:
                                    root.theme.fontFamily
                                font.pixelSize:
                                    root.theme.fontSize - 1

                                elide:
                                    Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text:
                                root.speedLabel(
                                    modelData
                                )

                            visible:
                                text.length > 0

                            color: root.secondaryText

                            font.family:
                                root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize - 1
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            width: 50
                            height: 28

                            color:
                                hoverEdit.hovered
                                    ? root.theme.accent
                                    : "transparent"

                            border.width: 1
                            border.color:
                                root.secondaryText

                            visible:
                                root.profileFor(
                                    modelData
                                ) !== null

                            Text {
                                anchors.centerIn: parent

                                text: "EDIT"

                                color: root.theme.fg

                                font.family:
                                    root.theme.fontFamily
                                font.pixelSize:
                                    root.theme.fontSize - 2
                                font.weight: Font.Bold
                            }

                            HoverHandler {
                                id: hoverEdit
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.openEditor(
                                        modelData,
                                        card
                                    )
                                }
                            }
                        }

                        Rectangle {
                            id: actionButton

                            readonly property bool noLink:
                                modelData.type === DeviceType.Wired &&
                                !modelData.connected &&
                                !modelData.hasLink

                            width:
                                modelData.connected
                                    ? 92
                                    : noLink
                                        ? 72
                                        : 72

                            height: 28

                            color:
                                noLink
                                    ? "transparent"
                                    : (
                                        hoverAction.hovered ||
                                        !modelData.connected
                                            ? root.theme.accent
                                            : "transparent"
                                    )

                            border.width: 1
                            border.color:
                                noLink
                                    ? root.secondaryText
                                    : root.secondaryText

                            opacity: noLink ? 0.45 : 1

                            Text {
                                anchors.centerIn: parent

                                text:
                                    modelData.connected
                                        ? "DISCONNECT"
                                        : actionButton.noLink
                                            ? "NO LINK"
                                            : "CONNECT"

                                color: root.theme.fg

                                font.family:
                                    root.theme.fontFamily
                                font.pixelSize:
                                    root.theme.fontSize - 2
                                font.weight: Font.Bold
                            }

                            HoverHandler {
                                id: hoverAction
                            }

                            MouseArea {
                                anchors.fill: parent

                                enabled: !actionButton.noLink

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.toggleDevice(
                                        modelData
                                    )
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    MouseArea {
                        id: cardMouseArea

                        anchors.fill: parent
                        z: -1

                        propagateComposedEvents: true

                        onClicked: function(mouse) {
                            root.selectDevice(modelData)
                            mouse.accepted = false
                        }
                    }
                }
            }

            // ==================================================
            // CLOUDFLARE WARP
            // ==================================================

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            // Name on the left, state chip on the right, one line. The chip has a FIXED width
            // (sized for the longest label) so it does not grow the moment it says CONNECTED, and
            // its right edge lines up with the other right-aligned controls in this panel.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                spacing: 10

                Text {
                    text: "Cloudflare WARP"

                    color: root.theme.accent

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 2
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: warpChip

                    readonly property bool on: root.warpStatus === "On"

                    // Fixed 120 x 34 whatever the state says, so the chip never resizes.
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter

                    color: "transparent"
                    radius: 0
                    border.width: 1
                    border.color: warpHover.hovered ? root.theme.accent : root.secondaryText
                    opacity: root.warpBusy ? 0.6 : 1

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7

                            color: warpChip.on ? root.theme.accent : root.theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.warpBusy
                                ? "WORKING"
                                : warpChip.on
                                    ? "CONNECTED"
                                    : root.warpStatus === "Not registered"
                                        ? "REGISTER"
                                        : root.warpStatus === "Checking"
                                            ? "CHECKING"
                                            : "OFF"

                            color: warpChip.on ? root.theme.fg : root.secondaryText

                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSize - 2
                            font.weight: Font.Bold
                        }
                    }

                    HoverHandler {
                        id: warpHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.warpBusy
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.warpToggle()
                    }
                }
            }

            // ==================================================
            // DETAILS
            // ==================================================

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            Text {
                text: "DETAILS"

                color: root.theme.accent

                font.family: root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize + 2
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.18
            }

            GridLayout {
                columns: 2

                columnSpacing: 12
                rowSpacing: 5

                Layout.fillWidth: true

                Text {
                    text: "Profile"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                }

                Text {
                    text:
                        root.profileFor(
                            root.selectedDevice
                        ) || "--"

                    color: root.theme.fg

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize
                    font.weight: Font.Bold

                    horizontalAlignment:
                        Text.AlignRight

                    elide:
                        Text.ElideLeft

                    Layout.fillWidth: true
                }

                Text {
                    text: "Interface"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                }

                Text {
                    text:
                        root.selectedDevice
                            ? root.selectedDevice.name
                            : "--"

                    color: root.theme.fg

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize
                    font.weight: Font.Bold

                    horizontalAlignment:
                        Text.AlignRight

                    Layout.fillWidth: true
                }

                Text {
                    text: "State"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                }

                Text {
                    text: root.detailState || "--"

                    color: root.theme.fg

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize
                    font.weight: Font.Bold

                    horizontalAlignment:
                        Text.AlignRight

                    Layout.fillWidth: true
                }

                Text {
                    text: "IPv4"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                }

                Text {
                    text: root.detailIp || "--"

                    color: root.theme.fg

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize
                    font.weight: Font.Bold

                    horizontalAlignment:
                        Text.AlignRight

                    Layout.fillWidth: true
                }

                Text {
                    text: "Gateway"
                    color: root.secondaryText
                    font.family: root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                }

                Text {
                    text:
                        root.detailGateway || "None"

                    color: root.theme.fg

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize
                    font.weight: Font.Bold

                    horizontalAlignment:
                        Text.AlignRight

                    Layout.fillWidth: true
                }
            }

            // ==================================================
            // SPEED TEST
            // ==================================================

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "SPEED TEST"

                    color: root.theme.accent

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 2
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                // ONE control, like a dashboard: the dial glyph starts a run. It replaced the two
                // TEST DOWN / TEST UP chips - a single press measures download then upload anyway.
                Rectangle {
                    id: speedRunButton

                    width: 34
                    height: 34

                    color: "transparent"
                    radius: 0
                    border.width: 1
                    border.color: (speedRunMouse.containsMouse || root.speedRunning)
                        ? root.theme.accent
                        : root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text: String.fromCodePoint(0xF0E4) // tachometer
                        color: (root.speedRunning || speedRunMouse.containsMouse)
                            ? root.theme.accent
                            : root.theme.fg

                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize + 4
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: speedRunMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.runSpeedTest("both")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                SpeedGauge {
                    width: 116
                    height: 132

                    label: "DOWNLOAD"
                    live: root.speedRunning && root.speedDirection === "down"
                    value: root.speedRunning && root.speedDirection === "down"
                        ? root.speedLive
                        : root.speedLastDown
                    fullScale: root.speedScale
                }

                SpeedGauge {
                    width: 116
                    height: 132

                    label: "UPLOAD"
                    live: root.speedRunning && root.speedDirection === "up"
                    value: root.speedRunning && root.speedDirection === "up"
                        ? root.speedLive
                        : root.speedLastUp
                    fullScale: root.speedScale
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true

                        text: root.speedRunning
                            ? (root.speedDirection === "up" ? "measuring upload…" : "measuring download…")
                            : root.speedStatusText

                        color: root.secondaryText

                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize - 1
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true

                        text: "Fast.com · Netflix OCA"

                        color: root.secondaryText
                        opacity: 0.75

                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize - 2
                    }
                }
            }
        }

        // --------------------------------------------------
        // ERROR TOAST
        // --------------------------------------------------

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10

            visible: root.errorVisible

            implicitHeight:
                errorMessage.implicitHeight + 18

            color: root.theme.panel

            border.width: 2
            border.color: root.theme.warning

            z: 100

            Text {
                id: errorMessage

                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                anchors.leftMargin: 10
                anchors.rightMargin: 8
                anchors.topMargin: 9
                anchors.bottomMargin: 9

                text: root.errorText

                color: root.theme.fg

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 2

                wrapMode: Text.WordWrap
                verticalAlignment:
                    Text.AlignVCenter
            }

            Text {
                id: closeButton

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: 28

                text: "×"

                color: root.theme.fg

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize + 2
                font.weight: Font.Bold

                horizontalAlignment:
                    Text.AlignHCenter
                verticalAlignment:
                    Text.AlignVCenter

                MouseArea {
                    anchors.fill: parent

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        root.errorVisible = false
                    }
                }
            }
        }
    }

    // --------------------------------------------------
    // EDIT POPUP
    // --------------------------------------------------

    NetworkEditPopup {
        id: editor

        // Stretched over the panel instead of opening a window of its own: the editor draws the
        // same theme.bg + 2px accent border, so this reads as the panel switching page.
        anchors.fill: parent

        visible:
            root.editorOpen &&
            root.editorProfile.length > 0

        profileName:
            root.editorProfile

        interfaceName:
            root.editorInterface

        wasConnected:
            root.editorWasConnected

        onSaved: {
            root.editorOpen = false
            root.refreshProfiles()
            root.refreshDetails()
        }

        onCancelled: {
            root.editorOpen = false
        }
    }

    // --------------------------------------------------
    // POPUP LIFECYCLE
    // --------------------------------------------------

    onVisibleChanged: {
        if (!visible) {
            root.editorOpen = false
            root.errorVisible = false
            return
        }

        root.refreshProfiles()

        const list = root.devices

        if (
            !root.selectedDevice &&
            list.length > 0
        ) {
            root.selectedDevice =
                list.find(
                    device => device.connected
                ) || list[0]
        }

        // Reset daemon-transition state so a stuck busy flag can never
        // leave the toggle dead, then read the real status again.
        root.warpBusy = false
        root.warpPollsLeft = 0
        root.warpQueue = []
        root.refreshDetails()
        root.warpRefresh()
    }

    onDevicesChanged: {
        if (!root.selectedDevice)
            return

        const exists =
            root.devices.some(
                device =>
                    device.name ===
                    root.selectedDevice.name
            )

        if (!exists) {
            root.selectedDevice =
                root.devices.length > 0
                    ? root.devices[0]
                    : null
        }
    }

    PopupKeys {
      active: root.open
    }
}
