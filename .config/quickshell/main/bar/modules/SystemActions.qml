import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "../../theme"
import "../../popups"

Item {
    id: root

    // The screen of the bar that hosts this module, passed down from Bar.qml
    // through Right.qml. Needed for the popup: a popup window does not
    // inherit the screen of the bar that creates it.
    required property var screen

    readonly property Theme theme: Theme {}

    // Popups are owned by PopupManager; see services/PopupManager.qml.
    readonly property bool popupOpen: PopupManager.isOpen(root.screenName, "system")

    // This module's screen (its bar window), used to key per-screen popup state.
    readonly property string screenName: root.screen ? root.screen.name : ""

    implicitWidth: icon.implicitWidth
    implicitHeight: theme.barHeight

    Text {
        id: icon

        anchors.centerIn: parent

        text: ""
        // Hover affordance, same convention as Network and Audio.
        color: hover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold

        rightPadding: 22
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "system")
    }

    Process {
        id: actionProcess

        // Power actions go through logind, which answers "challenge" (auth_admin_keep) for
        // suspend / reboot / power-off: they need an interactive polkit authorisation. When
        // that does not happen the command fails, and it used to fail SILENTLY - the popup
        // closed and nothing else was visible, which looks exactly like a dead button.
        // Report both channels so a failure lands in the shell log.
        onExited: function (exitCode) {
            // Non-zero is the interesting case: logind/polkit refusals surface here, e.g.
            // "Access denied as the requested operation requires interactive authentication".
            if (exitCode === 0)
                console.log("power action " + actionProcess.command + " -> ok (exit 0)")
            else
                console.warn("power action " + actionProcess.command + " -> FAILED (exit " + exitCode + ")")
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text !== "")
                    console.warn("power action stderr: " + text)
            }
        }
    }

    function runAction(command) {
        PopupManager.close(root.screenName)

        // A Process must not be stopped and restarted in the same tick: that silently
        // drops the new command. Stop it only when it is actually running.
        if (actionProcess.running)
            actionProcess.running = false

        actionProcess.command = command
        actionProcess.running = true
    }

    SystemPopup {
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

        onLockRequested: root.runAction([
            Quickshell.env("HOME") + "/System/.config/quickshell/scripts/qs-lock"
        ])

        onLogoutRequested: root.runAction([
            "niri",
            "msg",
            "action",
            "quit"
        ])

        onSuspendRequested: root.runAction([
            "systemctl",
            "suspend"
        ])

        onRestartRequested: root.runAction([
            "systemctl",
            "reboot"
        ])

        onShutdownRequested: root.runAction([
            "systemctl",
            "poweroff"
        ])
    }
}
