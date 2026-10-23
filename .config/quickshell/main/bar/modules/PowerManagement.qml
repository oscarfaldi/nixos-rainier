import Quickshell
import QtQuick
import qs.services
import "../../theme"
import "../../popups"

// Launcher for the power management panel (display timeout, idle suspend, one-time
// suspend timer, keep awake). It sits between the tray and the power menu, i.e.
// immediately to the left of the Power Menu launcher; see Right.qml for the optical
// spacing that position needs.
Item {
    id: root

    // The screen of the bar that hosts this module, passed down from Bar.qml through
    // Right.qml. Needed for the popup: a popup window does not inherit the screen of
    // the bar that creates it.
    required property var screen

    readonly property Theme theme: Theme { }

    // Popups are owned by PopupManager; see services/PopupManager.qml.
    readonly property bool popupOpen: PopupManager.isOpen(root.screenName, "power")
    readonly property string screenName: root.screen ? root.screen.name : ""

    implicitWidth: icon.implicitWidth
    implicitHeight: theme.barHeight

    Text {
        id: icon

        anchors.centerIn: parent

        // Font Awesome crescent moon (U+F186): idle and sleep policy, so it must not
        // look like a battery gauge or a CPU performance profile. Font Awesome on
        // purpose - the speaker, the network glyph and the power circle next door are the
        // same family, and its outline weight matches the power ring this icon sits next
        // to. (The Material "weather-night" crescent was tried first: it carries a small
        // star, i.e. a cultural emblem rather than a plain sleep symbol, and it is
        // denser than the ring beside it.)
        //
        // Built with String.fromCodePoint ON PURPOSE, never as a "\uXXXX" escape: a JS
        // string escape takes exactly FOUR hex digits, so a five-digit codepoint written
        // that way silently renders a different glyph plus a stray digit.
        text: String.fromCodePoint(0xF186)

        // Hover affordance, same convention as Network, Audio and SystemActions.
        color: hover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "power")
    }

    PowerPopup {
        id: popup

        // Screen of the bar that owns this popup (see `screen` above): a popup window
        // does not inherit it, so without this binding it lands on whichever screen
        // Quickshell picks as default.
        screen: root.screen

        open: root.popupOpen

        // Leave exactly this panel's area open in the click shield.
        onOpenChanged: {
            if (open)
                PopupManager.claimSlot(width, height)
        }
    }
}
