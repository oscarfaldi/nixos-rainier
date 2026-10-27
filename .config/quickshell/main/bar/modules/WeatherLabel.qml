import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"

// Weather segment of the center group: a separator and, as its own click target, the
// condition glyph plus the temperature, which together open the Weather panel.
//
// The separator sits OUTSIDE the click target: it has no handler, no hover colour and
// never changes when the icon or the temperature is hovered. It keeps the same
// brightness as the rest of the bar (a dim separator read as a darker, separate piece
// of the line - owner's report).
//
// Hidden until the first reading arrives, so the bar never shows a placeholder that
// has to be replaced a second later.
Item {
  id: root

  required property var screen

  readonly property Theme theme: Theme {}
  readonly property string screenName: root.screen ? root.screen.name : ""

  visible: Weather.ready
  implicitWidth: row.implicitWidth
  implicitHeight: root.theme.barHeight

  // Right edge of the drawn content, in this item's own coordinates. The row is centred inside the
  // item, so its right edge is width/2 + row.width/2 - NOT `width` (which is 0 for these bar items).
  // The countdown/alarm readout hangs off this instead of guessing from Center.right.
  readonly property real contentRight: root.width / 2 + row.width / 2

  Row {
    id: row

    anchors.centerIn: parent
    spacing: 0

    // -------------------------------------------------------------- separator
    // Inert on purpose, like the two in the clock label.
    Text {
      text: "|"
      color: root.theme.fg

      anchors.verticalCenter: parent.verticalCenter

      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize
      font.weight: Font.Bold
    }

    // ----------------------------------------------------------- click target
    Item {
      id: weatherCell

      width: weatherRow.implicitWidth + 16
      height: root.implicitHeight

      Row {
        id: weatherRow

        anchors.centerIn: parent
        spacing: 7

        Text {
          text: Weather.icon
          color: weatherHover.hovered ? root.theme.accent : root.theme.fg

          anchors.verticalCenter: parent.verticalCenter

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize
          font.weight: Font.Bold
        }

        Text {
          text: Weather.tempText
          color: weatherHover.hovered ? root.theme.accent : root.theme.fg

          anchors.verticalCenter: parent.verticalCenter

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize
          font.weight: Font.Bold
        }
      }

      HoverHandler {
        id: weatherHover
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "popup", "weather")
      }
    }
  }
}
