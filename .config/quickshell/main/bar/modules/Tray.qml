import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "../../theme"

Item {
  readonly property Theme theme: Theme {}

  // Collapses to zero width when the tray is empty (RowLayout skips
  // invisible children, spacing included), so an empty tray never leaves
  // a phantom gap between its neighbors.
  // The NetworkManager applet is filtered out below, so visibility must be
  // driven by the FILTERED list. Counting the raw list kept this module
  // visible-but-empty: zero width, yet RowLayout still paid its 20px
  // spacing on both sides, which read as "audio to power is too far".
  readonly property var visibleItems: {
    const items = SystemTray.items.values || []
    return items.filter(function (item) {
      const id = String(item.id || "")
      const title = String(item.title || "")
      return (
        !id.toLowerCase().includes("network") &&
        !title.toLowerCase().includes("network")
      )
    })
  }
  readonly property bool hasItems: visibleItems.length > 0
  visible: hasItems

  implicitWidth: hasItems ? trayRow.implicitWidth : 0
  implicitHeight: root.theme.barHeight

  RowLayout {
    id: trayRow
    anchors.centerIn: parent
    spacing: 18

    Repeater {
      // The NetworkManager applet is hidden by owner request; it is a
      // plain computer glyph in the bar and the Network module already
      // shows live connection state. The filter lives in visibleItems so
      // the module collapses when nothing is left to show.
      model: root.visibleItems

      delegate: Item {
        required property var modelData

        width: 18
        height: 18

        Image {
          anchors.centerIn: parent
          width: 16
          height: 16
          source: modelData.icon
          sourceSize.width: 16
          sourceSize.height: 16
          fillMode: Image.PreserveAspectFit
        }

        MouseArea {
          anchors.fill: parent

          cursorShape: Qt.PointingHandCursor

          onClicked: {
            if (mouse.button === Qt.RightButton && modelData.hasMenu) {
              modelData.display(root, 0, root.height);
            } else if (mouse.button === Qt.MiddleButton) {
              modelData.secondaryActivate();
            } else {
              modelData.activate();
            }
          }
        }
      }
    }
  }
}