import QtQuick
import qs.services

// Escape closes whichever panel is open.
//
// Two halves are needed, and this file covers the key itself:
//  - the SURFACE must hold keyboard focus, otherwise the key goes to the app underneath. That is
//    `WlrLayershell.keyboardFocus` on each popup's root, not something a child can do;
//  - the key must be caught window-wide, because a focused TextInput would otherwise keep it. A
//    `Shortcut` fires regardless of which item holds focus, unlike `Keys.onEscapePressed`.
//
// A layer-shell surface is not a window, so the compositor's close-window key can never reach it -
// it closes the focused window underneath instead (that is how a browser got closed once).
Item {
  id: root

  // The panel's visible state: the shortcut only exists while the panel does.
  required property bool active

  anchors.fill: parent

  // Nothing to draw, and a plain Item takes no input, so the panel below keeps its own handlers.
  Shortcut {
    sequence: "Escape"
    enabled: root.active
    onActivated: PopupManager.closeAll()
  }
}
