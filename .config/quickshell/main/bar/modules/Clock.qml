import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"

// Clock label in the center of the bar, split into TWO independent segments:
// the date opens the Calendar panel, the time opens the Clock & Timer panel. The
// "|" between them is inert - no handler, no hover state, never changes colour - so
// it cannot be mistaken for a third target or light up when a neighbour is hovered.
//
// The row keeps the exact width the old single label had: each cell carries the same
// 8 px of breathing room the old text padding gave, the separator is the same glyph,
// and the row spacing is 0 (8 + | + 8 = the old " | "). The clock therefore stays
// dead center, which the owner treats as a hard requirement.
Item {
  id: root

  required property var screen

  readonly property Theme theme: Theme {}
  readonly property string screenName: root.screen ? root.screen.name : ""

  property date now: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true

    onTriggered: root.now = new Date()
  }

  readonly property string dateLabel: {
    const days = ["Sunday", "Monday", "Tuesday", "Wednesday",
                  "Thursday", "Friday", "Saturday"]
    const months = ["January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"]
    const d = root.now

    return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
      + " " + d.getFullYear()
  }

  readonly property string timeLabel: {
    const d = root.now
    return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
  }

  implicitWidth: row.implicitWidth
  implicitHeight: root.theme.barHeight

  Row {
    id: row

    anchors.centerIn: parent
    spacing: 0

    // ------------------------------------------------------------------- date
    Item {
      id: dateCell

      // 8px padding, calendar glyph, 7px gap, the date, 8px padding - the same rhythm the weather
      // segment uses between its icon and its temperature.
      width: 8 + dateIcon.implicitWidth + 7 + dateText.implicitWidth + 8
      height: root.implicitHeight

      Text {
        id: dateIcon

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        text: String.fromCodePoint(0xF073) // calendar
        color: dateHover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      Text {
        id: dateText

        anchors.left: dateIcon.right
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter

        text: root.dateLabel
        color: dateHover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      HoverHandler {
        id: dateHover
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "popup", "date")
      }
    }

    // -------------------------------------------------------------- separator
    // Deliberately inert: plain text, fixed colour, no handler of its own.
    Text {
      text: "|"
      color: root.theme.fg

      anchors.verticalCenter: parent.verticalCenter

      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize
      font.weight: Font.Bold
    }

    // ------------------------------------------------------------------- time
    Item {
      id: timeCell

      width: 8 + timeIcon.implicitWidth + 7 + timeText.implicitWidth + 8
      height: root.implicitHeight

      Text {
        id: timeIcon

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        text: String.fromCodePoint(0xF017) // clock
        color: timeHover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      Text {
        id: timeText

        anchors.left: timeIcon.right
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter

        text: root.timeLabel
        color: timeHover.hovered ? root.theme.accent : root.theme.fg

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      HoverHandler {
        id: timeHover
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        acceptedButtons: Qt.LeftButton

        onTapped: PopupManager.toggle(root.screenName, "popup", "clock")
      }
    }
  }
}
