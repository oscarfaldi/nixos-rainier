import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"
import "../../services/CalendarMath.js" as Calendar

// DATE tab of ShellPopup: the month grid, week numbers, today highlight and the
// selected-day line. It owns ONLY the calendar; the clock, year progress, countdown
// and alarm live in ClockTab.
//
// Shown when the bar's date segment opens the popup (the bar only chooses the tab).
// The title centers on the SEVEN day columns, not on the whole grid including the
// week column, which was an explicit fix in an earlier revision.
Item {
  id: root

  // TAB of ShellPopup, not a window of its own: the popup owns the screen, the fixed
  // size, the shared header and the tab navigation. `activeTab` comes from the popup and
  // drives both visibility and every internal timer.
  property bool activeTab: false

  visible: activeTab

  readonly property Theme theme: Theme {}
  readonly property color secondaryText: "#bdae93"

  // ---------------------------------------------------------------- state
  readonly property int weekStart: 1
  readonly property var weekdaysShort: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
  readonly property var weekdaysLong: ["Monday", "Tuesday", "Wednesday", "Thursday",
                                       "Friday", "Saturday", "Sunday"]
  readonly property var monthsLong: ["January", "February", "March", "April", "May", "June",
                                     "July", "August", "September", "October", "November", "December"]

  property date now: new Date()
  property int viewYear: now.getFullYear()
  property int viewMonth: now.getMonth()
  property string selectedKey: ""

  readonly property string todayKey: Calendar.keyForDate(now)
  readonly property var weeks: Calendar.monthGrid(viewYear, viewMonth, weekStart, todayKey)

  Timer {
    interval: 1000
    running: root.activeTab
    repeat: true

    onTriggered: root.now = new Date()
  }

  // Becoming the active tab always starts on the current month, even if the owner left
  // it browsing next year.
  onActiveTabChanged: {
    if (!activeTab)
      return

    viewYear = now.getFullYear()
    viewMonth = now.getMonth()
  }

  function step(delta) {
    const next = Calendar.stepMonth(root.viewYear, root.viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function selectDay(day) {
    root.selectedKey = day.key

    if (!day.inMonth) {
      root.viewYear = day.year
      root.viewMonth = day.month
    }
  }

  readonly property var selectedDay: {
    if (root.selectedKey === "")
      return null

    for (let w = 0; w < weeks.length; w++)
      for (let d = 0; d < weeks[w].days.length; d++)
        if (weeks[w].days[d].key === root.selectedKey)
          return weeks[w].days[d]

    return null
  }

  // ---------------------------------------------------------------- shell
  Item {
    anchors.fill: parent

      // ------------------------------------------------------------- calendar
      // Fixed 320 px grid centred inside the popup's 765 px content area: the panel is
      // shared with CLOCK and WEATHER, so letting the grid fill the width would stretch
      // the 42 px day columns the owner approved.
      ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320
        height: parent.height
        spacing: 6

        // month navigation: two EQUAL button pairs (28 + 6 + 28 = 62 px) whose OUTER
        // edges align with the grid itself - the left pair's left edge with the W
        // column's outer edge, the right pair's right edge with the SUN label's. The
        // title carries a 26 px left margin (the week column) so it stays centred on
        // the seven DAY columns, not on the title's own cell.
        RowLayout {
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.topMargin: 8
          spacing: 8

          RowLayout {
            spacing: 6

            NavKey {
              text: "\u2039\u2039"
              onActivated: root.step(-12)
            }

            NavKey {
              text: "\u2039"
              onActivated: root.step(-1)
            }
          }

          Text {
            // maximumWidth raised: a fillWidth Text is capped at its own implicit
            // width and then it could never centre in its cell.
            Layout.fillWidth: true
            Layout.maximumWidth: 100000
            // 26 px = the week-number column, so the title centres on the seven DAY
            // columns even though the container now spans the whole grid (the button
            // pairs sit flush with the W and SUN outer edges).
            Layout.leftMargin: 26

            text: root.monthsLong[root.viewMonth].toUpperCase() + " " + root.viewYear
            color: root.theme.fg
            horizontalAlignment: Text.AlignHCenter

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize + 1
            font.weight: Font.Bold
          }

          RowLayout {
            spacing: 6

            NavKey {
              text: "\u203A"
              onActivated: root.step(1)
            }

            NavKey {
              text: "\u203A\u203A"
              onActivated: root.step(12)
            }
          }
        }

        // weekday header, kept on the same rhythm as the day rows below
        RowLayout {
          Layout.topMargin: 6
          Layout.bottomMargin: 2
          Layout.preferredHeight: 24
          spacing: 0

          Text {
            text: "W"
            color: root.secondaryText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 3
            font.weight: Font.Bold

            Layout.preferredWidth: 26
            Layout.fillHeight: true
          }

          Repeater {
            model: root.weekdaysShort

            delegate: Text {
              required property string modelData

              text: modelData
              color: root.secondaryText
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize - 3
              font.weight: Font.Bold

              Layout.preferredWidth: 42
              Layout.fillHeight: true
            }
          }
        }

        // week rows share the leftover height, so the pitch stays even and the last
        // row keeps its distance from the bottom border
        Repeater {
          model: root.weeks

          delegate: RowLayout {
            required property var modelData

            Layout.fillHeight: true
            spacing: 0

            Text {
              text: modelData.week
              color: root.secondaryText
              opacity: 0.7
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize - 4

              Layout.preferredWidth: 26
              Layout.preferredHeight: 28
            }

            Repeater {
              model: modelData.days

              delegate: DayCell {
                required property var modelData

                day: modelData
              }
            }
          }
        }

        // The selected-day line used to live in the clock column of the combined
        // panel. It is calendar information, so it belongs here.
        Text {
          visible: root.selectedDay !== null
          text: root.selectedDay === null
            ? ""
            : "SELECTED  " + root.weekdaysLong[(root.selectedDay.weekday + 6) % 7].toUpperCase()
              + ", " + root.selectedDay.day + " " + root.monthsLong[root.selectedDay.month].toUpperCase()
              + " " + root.selectedDay.year
          color: root.theme.accent

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize - 2
          font.weight: Font.Bold
        }
      }
    }

  // ------------------------------------------------------------------ pieces
  // A nav key: flat text button, hover turns it accent and thickens the border to
  // 2 px. Fixed 28 x 26 so the four read as one component system instead of four
  // widths taken from their glyphs.
  component NavKey: Rectangle {
    id: navKey

    property string text: ""

    signal activated()

    implicitWidth: 28
    implicitHeight: 26

    color: navHover.hovered
      ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.18)
      : "transparent"
    border.width: 1
    border.color: navHover.hovered ? root.theme.accent : root.secondaryText
    radius: 0

    Text {
      id: navLabel

      anchors.centerIn: parent

      text: navKey.text
      color: navHover.hovered ? root.theme.accent : root.theme.fg

      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize - 2
      font.weight: Font.Bold
    }

    HoverHandler {
      id: navHover
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton
      onTapped: navKey.activated()
    }
  }

  // One day: today carries an accent border, the selected day an accent fill, and
  // days outside the month dim down but stay clickable (they jump the month, which
  // is what a click on a trailing day should do).
  component DayCell: Rectangle {
    id: cell

    required property var day

    readonly property bool isToday: day.today
    readonly property bool isSelected: root.selectedKey === day.key

    Layout.preferredWidth: 42
    Layout.preferredHeight: 28

    color: isSelected
      ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25)
      : "transparent"
    border.width: isToday || isSelected ? 2 : 0
    border.color: root.theme.accent
    radius: 0

    Text {
      anchors.centerIn: parent

      text: cell.day.day
      color: cell.isSelected || cell.isToday
        ? root.theme.accent
        : (cell.day.inMonth
            ? (cell.day.weekend ? root.secondaryText : root.theme.fg)
            : Qt.rgba(root.secondaryText.r, root.secondaryText.g, root.secondaryText.b, 0.32))

      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize - 1
      font.weight: Font.Bold
    }

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton
      onTapped: root.selectDay(cell.day)
    }
  }
}
