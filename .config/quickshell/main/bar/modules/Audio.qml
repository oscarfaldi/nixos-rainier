import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
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
    readonly property var sink: Pipewire.defaultAudioSink

    // Popups are owned by PopupManager; see services/PopupManager.qml.
    readonly property bool popupOpen: PopupManager.isOpen(root.screenName, "audio")
    readonly property string screenName: root.screen ? root.screen.name : ""


    PwObjectTracker {
        objects: [root.sink]
    }

    implicitWidth: audioIcon.implicitWidth
    implicitHeight: theme.barHeight

    function volumeIcon() {
        if (!root.sink || !root.sink.audio)
            return ""

        if (
            root.sink.audio.muted ||
            root.sink.audio.volume <= 0
        )
            return ""

        return ""
    }

    Text {
        id: audioIcon

        anchors.centerIn: parent

        text: root.volumeIcon()

        // Hover affordance: same treatment as the Network module, so every
        // clickable module signals "this opens a popup" before the click.
        color: hover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "audio")
    }

    AudioPopup {
        id: audioPopup

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