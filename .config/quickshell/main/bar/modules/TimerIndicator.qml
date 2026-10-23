import QtQuick
import qs.services
import "../../theme"

// Countdown and alarm readout for the bar's centre group, right of the weather.
//
// Structure mirrors the rest of the centre group: one inert "|" separator (same glyph, same
// colour, no handler) per active segment, then a click target that opens the CLOCK tab. Two active
// segments therefore read as `| hourglass 01:29 | bell 04:30`, exactly the language the date/time
// and weather segments already use.
//
// Colour stays `theme.fg` like the rest of the line; accent is reserved for hover. A PAUSED
// countdown drops to the dim colour, because "paused" has to read differently from "running".
//
// Nothing is drawn when neither is active: a status element that is usually absent must be absent,
// not dimmed, or the bar looks broken.
Item {
  id: root

  required property var screen

  readonly property Theme theme: Theme {}
  readonly property string screenName: root.screen ? root.screen.name : ""
  readonly property color dim: "#bdae93"

  readonly property bool showCountdown: TimerService.cdStatus === "running"
    || TimerService.cdStatus === "paused"
  readonly property bool showAlarm: TimerService.alarmArmed || TimerService.alarmRinging

  visible: root.showCountdown || root.showAlarm
  // `width` as well as `implicitWidth`: the row below is centred in this item, so a zero width
  // would straddle it around the anchor point instead of starting there.
  implicitWidth: row.implicitWidth
  width: row.implicitWidth
  implicitHeight: root.theme.barHeight

  function two(value) {
    return String(value).padStart(2, "0")
  }

  // MM:SS below an hour, H:MM:SS above. Ceiled so a fresh timer shows its full duration instead
  // of one second less. Monospace keeps the width stable while it counts down.
  readonly property string countdownText: {
    const total = Math.max(0, Math.ceil(TimerService.cdRemainingMs / 1000))
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = total % 60
    const glyph = String.fromCodePoint(0xF254) // hourglass

    if (hours > 0)
      return glyph + " " + hours + ":" + root.two(minutes) + ":" + root.two(seconds)

    return glyph + " " + root.two(minutes) + ":" + root.two(seconds)
  }

  readonly property string alarmText: String.fromCodePoint(0xF0F3) + " " + TimerService.alarmTime

  Row {
    id: row

    spacing: 0

    // -------------------------------------------------------------- countdown
    Row {
      visible: root.showCountdown
      spacing: 0

      Text {
        text: "|"
        color: root.theme.fg

        anchors.verticalCenter: parent.verticalCenter

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      Item {
        width: countdownLabel.implicitWidth + 16
        height: root.implicitHeight

        Text {
          id: countdownLabel

          anchors.centerIn: parent

          text: root.countdownText
          color: TimerService.cdStatus === "running"
            ? (countdownHover.hovered ? root.theme.accent : root.theme.fg)
            : root.dim

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize
          font.weight: Font.Bold
        }

        HoverHandler {
          id: countdownHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton

          onTapped: PopupManager.toggle(root.screenName, "popup", "clock")
        }
      }
    }

    // ------------------------------------------------------------------ alarm
    Row {
      visible: root.showAlarm
      spacing: 0

      Text {
        text: "|"
        color: root.theme.fg

        anchors.verticalCenter: parent.verticalCenter

        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.weight: Font.Bold
      }

      Item {
        width: alarmLabel.implicitWidth + 16
        height: root.implicitHeight

        Text {
          id: alarmLabel

          anchors.centerIn: parent

          text: root.alarmText
          color: alarmHover.hovered ? root.theme.accent : root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize
          font.weight: Font.Bold
        }

        HoverHandler {
          id: alarmHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton

          onTapped: PopupManager.toggle(root.screenName, "popup", "clock")
        }
      }
    }
  }
}
