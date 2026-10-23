import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme"

// The connection editor as an EMBEDDED view, not its own window.
//
// It used to be a PopupWindow anchored to the pencil glyph, so editing opened a second floating
// window beside the panel. NetworkPopup now stretches this Item over its own surface and the
// Rectangle inside draws the same theme.bg + 2px accent border as the panel, so the swap reads as
// one page. Only the window properties were removed - the editor's internals are untouched.
Item {
    id: root

    property string profileName: ""
    property string interfaceName: ""
    property bool wasConnected: false

    signal saved()
    signal cancelled()

    readonly property Theme theme: Theme {}
    readonly property color secondaryText: "#bdae93"

    property bool manualMode: false
    property string statusText: ""
    property string errorText: ""

    function prefixToMask(prefix) {
        const p = Number(prefix)

        if (
            !Number.isFinite(p) ||
            p < 0 ||
            p > 32
        )
            return ""

        const octets = []
        let remaining = p

        for (let i = 0; i < 4; i++) {
            const bits = Math.max(
                0,
                Math.min(8, remaining)
            )

            octets.push(
                bits === 0
                    ? 0
                    : 256 -
                      Math.pow(2, 8 - bits)
            )

            remaining -= bits
        }

        return octets.join(".")
    }

    function maskToPrefix(mask) {
        const masks = {
            "255.255.255.255": 32,
            "255.255.255.254": 31,
            "255.255.255.252": 30,
            "255.255.255.248": 29,
            "255.255.255.240": 28,
            "255.255.255.224": 27,
            "255.255.255.192": 26,
            "255.255.255.128": 25,
            "255.255.255.0": 24,
            "255.255.254.0": 23,
            "255.255.252.0": 22,
            "255.255.248.0": 21,
            "255.255.240.0": 20,
            "255.255.224.0": 19,
            "255.255.192.0": 18,
            "255.255.128.0": 17,
            "255.255.0.0": 16,
            "255.254.0.0": 15,
            "255.252.0.0": 14,
            "255.248.0.0": 13,
            "255.240.0.0": 12,
            "255.224.0.0": 11,
            "255.192.0.0": 10,
            "255.128.0.0": 9,
            "255.0.0.0": 8,
            "254.0.0.0": 7,
            "252.0.0.0": 6,
            "248.0.0.0": 5,
            "240.0.0.0": 4,
            "224.0.0.0": 3,
            "192.0.0.0": 2,
            "128.0.0.0": 1,
            "0.0.0.0": 0
        }

        return masks[mask] !== undefined
            ? masks[mask]
            : -1
    }

    function isValidIpv4(value) {
        const parts =
            value
                .trim()
                .split(".")

        if (parts.length !== 4)
            return false

        for (let i = 0; i < 4; i++) {
            if (!/^\d+$/.test(parts[i]))
                return false

            const n = Number(parts[i])

            if (n < 0 || n > 255)
                return false
        }

        return true
    }

    function loadProfile() {
        if (!root.profileName)
            return

        loadProcess.running = false

        loadProcess.command = [
            "nmcli",
            "-t",
            "-f",
            "ipv4.method,ipv4.addresses,ipv4.gateway",
            "connection",
            "show",
            "id",
            root.profileName
        ]

        loadProcess.running = true
    }

    function applyProfile() {
        root.statusText = "Applying..."
        root.errorText = ""

        if (root.manualMode) {
            const ip = ipInput.text.trim()
            const mask = subnetInput.text.trim()
            const gateway = gatewayInput.text.trim()

            if (!root.isValidIpv4(ip)) {
                root.errorText =
                    "IPv4 address is invalid."
                return
            }

            if (!root.isValidIpv4(mask)) {
                root.errorText =
                    "Subnet mask is invalid."
                return
            }

            if (
                root.maskToPrefix(mask) < 0
            ) {
                root.errorText =
                    "Subnet mask is not a valid contiguous mask."
                return
            }

            if (
                gateway.length > 0 &&
                !root.isValidIpv4(gateway)
            ) {
                root.errorText =
                    "Default gateway is invalid."
                return
            }

            const prefix =
                root.maskToPrefix(mask)

            saveProcess.running = false

            const command = [
                "nmcli",
                "connection",
                "modify",
                "--temporary",
                "id",
                root.profileName,
                "ipv4.method",
                "manual",
                "ipv4.addresses",
                ip + "/" + prefix
            ]

            if (gateway.length > 0) {
                command.push(
                    "ipv4.gateway",
                    gateway
                )
            } else {
                command.push(
                    "ipv4.gateway",
                    ""
                )
            }

            saveProcess.command = command
            saveProcess.running = true

        } else {
            saveProcess.running = false

            saveProcess.command = [
                "nmcli",
                "connection",
                "modify",
                "--temporary",
                "id",
                root.profileName,
                "ipv4.method",
                "auto",
                "ipv4.addresses",
                "",
                "ipv4.gateway",
                ""
            ]

            saveProcess.running = true
        }
    }

    // --------------------------------------------------
    // PROFILE LOAD
    // --------------------------------------------------

    onVisibleChanged: {
        if (visible)
            root.loadProfile()
    }

    Process {
        id: loadProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    this.text
                        .replace(/\r/g, "")
                        .split("\n")

                root.manualMode =
                    (lines[0] || "auto") === "manual"

                const address =
                    (lines[1] || "").trim()

                if (address.includes("/")) {
                    const parts =
                        address.split("/")

                    ipInput.text = parts[0] || ""

                    const prefix =
                        Number(parts[1])

                    subnetInput.text =
                        root.prefixToMask(prefix)

                } else {
                    ipInput.text = ""
                    subnetInput.text = ""
                }

                gatewayInput.text =
                    (lines[2] || "").trim()

                root.statusText = ""
                root.errorText = ""
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.errorText =
                        this.text.trim()
            }
        }

        onExited: (code) => {
            if (
                code !== 0 &&
                !root.errorText
            ) {
                root.errorText =
                    "Unable to read the connection profile."
            }
        }
    }

    // --------------------------------------------------
    // SAVE
    // --------------------------------------------------

    Process {
        id: saveProcess

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.errorText =
                        this.text.trim()
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                root.statusText = ""

                if (!root.errorText)
                    root.errorText =
                        "Unable to apply changes."

                return
            }

            if (root.wasConnected) {
                reconnectProcess.running = false

                reconnectProcess.command = [
                    "nmcli",
                    "connection",
                    "up",
                    "id",
                    root.profileName,
                    "ifname",
                    root.interfaceName
                ]

                root.statusText =
                    "Reconnecting..."

                reconnectProcess.running = true
            } else {
                root.statusText =
                    "Applied for this session."

                closeTimer.restart()
            }
        }
    }

    // --------------------------------------------------
    // RECONNECT
    // --------------------------------------------------

    Process {
        id: reconnectProcess

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    root.errorText =
                        this.text.trim()
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                root.statusText = ""

                if (!root.errorText)
                    root.errorText =
                        "Saved, but reconnect failed."

                return
            }

            root.statusText =
                "Applied and reconnected."

            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer

        interval: 800
        repeat: false

        onTriggered:
            root.saved()
    }

    // --------------------------------------------------
    // MAIN UI
    // --------------------------------------------------

    Rectangle {
        anchors.fill: parent

        color: root.theme.panel

        border.width: 2
        border.color: root.theme.accent

        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            Text {
                text: "EDIT CONNECTION"

                color: root.theme.fg

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize + 3
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            Text {
                text:
                    root.profileName +
                    "  ·  " +
                    root.interfaceName

                color: root.secondaryText

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 1

                elide:
                    Text.ElideRight

                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            Text {
                text: "IPv4"

                color: root.theme.accent

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize + 2
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    height: 32

                    color:
                        !root.manualMode
                            ? root.theme.accent
                            : "transparent"

                    border.width: 1
                    border.color:
                        root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text: "DHCP"

                        color: root.theme.fg

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize - 1
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.manualMode = false
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32

                    color:
                        root.manualMode
                            ? root.theme.accent
                            : "transparent"

                    border.width: 1
                    border.color:
                        root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text: "MANUAL"

                        color: root.theme.fg

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize - 1
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.manualMode = true
                    }
                }
            }

            ColumnLayout {
                visible: root.manualMode

                Layout.fillWidth: true
                spacing: 7

                // ----------------------------
                // IPv4 Address
                // ----------------------------

                Text {
                    text: "IPV4 ADDRESS"

                    color: root.secondaryText

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                    font.weight: Font.Bold
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36

                    color: "transparent"

                    border.width: 1
                    border.color:
                        ipInput.activeFocus
                            ? root.theme.accent
                            : root.secondaryText

                    TextInput {
                        id: ipInput

                        anchors.fill: parent

                        anchors.leftMargin: 9
                        anchors.rightMargin: 9

                        color: root.theme.fg

                        selectionColor:
                            root.theme.accent

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize

                        verticalAlignment:
                            Text.AlignVCenter

                        selectByMouse: true
                    }
                }

                // ----------------------------
                // Subnet
                // ----------------------------

                Text {
                    text: "SUBNET MASK"

                    color: root.secondaryText

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                    font.weight: Font.Bold
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36

                    color: "transparent"

                    border.width: 1
                    border.color:
                        subnetInput.activeFocus
                            ? root.theme.accent
                            : root.secondaryText

                    TextInput {
                        id: subnetInput

                        anchors.fill: parent

                        anchors.leftMargin: 9
                        anchors.rightMargin: 9

                        color: root.theme.fg

                        selectionColor:
                            root.theme.accent

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize

                        verticalAlignment:
                            Text.AlignVCenter

                        selectByMouse: true

                        text: "255.255.255.0"
                    }
                }

                // ----------------------------
                // Gateway
                // ----------------------------

                Text {
                    text: "DEFAULT GATEWAY"

                    color: root.secondaryText

                    font.family:
                        root.theme.fontFamily
                    font.pixelSize:
                        root.theme.fontSize - 1
                    font.weight: Font.Bold
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36

                    color: "transparent"

                    border.width: 1
                    border.color:
                        gatewayInput.activeFocus
                            ? root.theme.accent
                            : root.secondaryText

                    TextInput {
                        id: gatewayInput

                        anchors.fill: parent

                        anchors.leftMargin: 9
                        anchors.rightMargin: 9

                        color: root.theme.fg

                        selectionColor:
                            root.theme.accent

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize

                        verticalAlignment:
                            Text.AlignVCenter

                        selectByMouse: true
                    }
                }
            }

            Text {
                visible:
                    !root.manualMode &&
                    !root.errorText.length

                text:
                    "DHCP obtains IP, subnet and gateway automatically."

                color: root.secondaryText

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 2

                wrapMode:
                    Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                visible:
                    root.manualMode &&
                    !root.errorText.length &&
                    !root.statusText.length

                text:
                    "Changes are temporary and intended for troubleshooting. NixOS configuration remains the source of truth."

                color: root.secondaryText

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 2

                wrapMode:
                    Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                visible: root.errorText.length > 0

                text: root.errorText

                color: root.theme.fg
                opacity: 0.9

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 2

                wrapMode:
                    Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                visible: root.statusText.length > 0

                text: root.statusText

                color: root.theme.fg

                font.family:
                    root.theme.fontFamily
                font.pixelSize:
                    root.theme.fontSize - 1
                font.weight: Font.Bold

                wrapMode:
                    Text.WordWrap

                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    height: 36

                    color: "transparent"

                    border.width: 1
                    border.color:
                        root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text: "CANCEL"

                        color: root.theme.fg

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.cancelled()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36

                    color: root.theme.accent

                    border.width: 1
                    border.color:
                        root.theme.accent

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.wasConnected
                                ? "APPLY & RECONNECT"
                                : "APPLY"

                        color: root.theme.fg

                        font.family:
                            root.theme.fontFamily
                        font.pixelSize:
                            root.theme.fontSize
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.applyProfile()
                    }
                }
            }
        }
    }
}
