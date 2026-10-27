import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import "../../theme"
import "../../popups"
import qs.services

Item {
    id: root

    // The screen of the bar that hosts this module, passed down from Bar.qml
    // through Right.qml. Needed for the popup: a popup window does not
    // inherit the screen of the bar that creates it.
    required property var screen

    readonly property Theme theme: Theme {}
    // Owned by PopupManager: opening one popup closes the previous one.
    readonly property bool popupOpen: PopupManager.isOpen(root.screenName, "network")
    readonly property string screenName: root.screen ? root.screen.name : ""

    // they always appear top-right below the bar (omarchy-style).

    property int downStreak: 0
    property bool netDown: false

    // First connected device. Wifi wins over wired when both are up.
    readonly property var device: {
        const devices = Networking.devices.values;
        let wired = null;

        for (let i = 0; i < devices.length; i++) {
            const d = devices[i];

            if (!d.connected)
                continue;

            if (d.type === DeviceType.Wifi)
                return d;

            if (d.type === DeviceType.Wired && !wired)
                wired = d;
        }

        return wired;
    }

    // For wifi, the connected network object; for wired, null.
    readonly property var wifiNetwork: {
        if (!root.device || root.device.type !== DeviceType.Wifi || !root.device.networks)
            return null;

        const networks = root.device.networks.values;

        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }

        return null;
    }

    // Link up is NOT internet up: a plugged cable behind a dead switch, or a DHCP lease without a
    // working upstream, still reports a connected device. `netDown` comes from the ping check below
    // and is what the label has to follow - the owner's bug report was exactly this: cable in,
    // internet dead, bar still showing "Up".
    readonly property bool online: root.healthy && !root.netDown

    readonly property string label: {
        if (!root.healthy || root.netDown)
            return "Down";

        if (root.device.type === DeviceType.Wired)
            return "Up";

        if (root.wifiNetwork)
            return root.wifiNetwork.ssid || "Up";

        return "Up";
    }

    // Real internet reachability: the upstream can be dead while the link
    // is up. Three consecutive failed 4s-apart pings mark it down.
    Process {
        id: pingProcess

        command: [ "ping", "-c", "1", "-W", "2", "1.1.1.1" ]

        onExited: (code) => {
            if (code === 0) {
                root.downStreak = 0
                root.netDown = false
            } else {
                root.downStreak = root.downStreak + 1

                if (root.downStreak >= 3)
                    root.netDown = true
            }
        }
    }

    Timer {
        interval: 4000
        // No connected device means the answer is already "Down"; pinging would be noise.
        running: root.healthy
        repeat: true

        onTriggered: {
            pingProcess.running = false
            pingProcess.running = true
        }
    }

    readonly property bool healthy: root.device !== null

    implicitWidth: labelRow.implicitWidth
    implicitHeight: theme.barHeight

    Row {
        id: labelRow

        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.healthy
                    ? (root.device.type === DeviceType.Wired ? "󰈀" : "󰖩")
                    : "󰖪"

            color: hover.hovered ? root.theme.accent : (root.online ? root.theme.fg : root.theme.warning)

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize
            font.weight: Font.Bold

            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.label

            color: hover.hovered ? root.theme.accent : (root.online ? root.theme.fg : root.theme.warning)

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize
            font.weight: Font.Bold

            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "network")
    }

    NetworkPopup {
        id: popup

        // A popup window does NOT inherit the screen of the bar that creates
        // it: without this binding Quickshell puts every popup on its default
        // screen, i.e. the popups of the other monitor opened here.
        // Screen of the bar that owns this popup (see `screen` above): a popup
        // window does not inherit it, so without this it lands on whichever
        // screen Quickshell picks as default.
        screen: root.screen

        open: root.popupOpen

        // Leave exactly this panel's area open in the click shield.
        onOpenChanged: {
            if (open)
                PopupManager.claimSlot(width, height)
        }

    }
}
