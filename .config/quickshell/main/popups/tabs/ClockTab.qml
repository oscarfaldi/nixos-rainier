import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"
import "../../services/CalendarMath.js" as Calendar

// CLOCK tab of ShellPopup: the digital clock on the left, the countdown/alarm module on
// the right, two equal columns over the popup's content area.
//
// The popup's own header already carries the tab name, so the left column does NOT
// repeat a "CLOCK" title - the digital clock is the first and dominant element.
//
// The countdown/alarm logic does NOT live here: services/TimerService.qml owns the state
// and the deadlines, so the timer keeps running while this tab (or the whole popup) is
// not showing, and this file is only the interface.
Item {
  id: root

  // TAB of ShellPopup: the popup owns the window, the fixed size and the header.
  property bool activeTab: false

  visible: activeTab

  readonly property Theme theme: Theme {}
  readonly property color secondaryText: "#bdae93"

  property date now: new Date()

  Timer {
    interval: 1000
    running: root.activeTab
    repeat: true

    onTriggered: root.now = new Date()
  }

  function pad2(value) {
    return value < 10 ? "0" + value : "" + value
  }

  readonly property string timeText:
    pad2(now.getHours()) + ":" + pad2(now.getMinutes()) + ":" + pad2(now.getSeconds())

  readonly property string dateText:
    ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][now.getDay()]
    + ", " + now.getDate() + " "
    + ["January", "February", "March", "April", "May", "June",
       "July", "August", "September", "October", "November", "December"][now.getMonth()]
    + " " + now.getFullYear()

  readonly property int yearPercent:
    Calendar.yearProgressPercent(now.getFullYear(), now.getMonth(), now.getDate())

  readonly property string todayInfo:
    "Week " + Calendar.isoWeek(now.getFullYear(), now.getMonth(), now.getDate())
    + "  \u00B7  day " + Calendar.dayOfYear(now.getFullYear(), now.getMonth(), now.getDate())
    + " of " + Calendar.daysInYear(now.getFullYear())

  // ------------------------------------------------------------- alarm (12-hour UI)
  // TimerService keeps the schedule as 24-hour "HH:MM". Everything the owner sees is
  // 12-hour with an AM/PM selector, converted at THIS boundary: the service, its deadline
  // maths, the notifier and the system clock are untouched.

  property string alarmDraftText: "07:30"    // the field's text, 12-hour HH:MM
  property bool alarmDraftPm: false          // the AM/PM selector, true = PM

  readonly property string alarmDraftValid:
    /^(0?[1-9]|1[0-2]):[0-5][0-9]$/.test(root.alarmDraftText) ? "yes" : "no"

  // "4:00 PM" from a 24-hour hour and the field's two-digit minute string.
  function display12(h, mm) {
    const pm = h >= 12
    let h12 = h % 12

    if (h12 === 0)
      h12 = 12

    return h12 + ":" + mm + (pm ? " PM" : " AM")
  }

  // The 12-hour field plus the selector -> the service's 24-hour "HH:MM".
  // 12 AM is midnight, 12 PM is noon.
  function draftToHh24() {
    const parts = root.alarmDraftText.split(":")

    if (parts.length !== 2)
      return ""

    let h = parseInt(parts[0])

    if (h === 12)
      h = 0

    h = h + (root.alarmDraftPm ? 12 : 0)

    return (h < 10 ? "0" : "") + h + ":" + parts[1]
  }

  // Reads the service's 24-hour value back into the field and the selector, and normalises
  // the field's text (so "4:00" becomes "04:00"). Never writes to the service.
  function resetAlarmDraft() {
    const parts = String(TimerService.alarmTime).split(":")

    if (parts.length !== 2)
      return

    const h = parseInt(parts[0])
    let h12 = h % 12

    if (h12 === 0)
      h12 = 12

    root.alarmDraftPm = h >= 12
    // The FIELD holds "HH:MM" only - the meridiem lives in the selector, never in the text
    // (putting it in the field overflows the 72 px width and breaks the validation).
    root.alarmDraftText = (h12 < 10 ? "0" : "") + h12 + ":" + parts[1]
    alarmInput.text = root.alarmDraftText
  }

  // Editing only touches the draft; the schedule is committed on Enter (or by clicking a
  // meridiem cell, which is an explicit choice). An invalid field keeps the last valid
  // target and keeps the warning colour visible.
  function commitAlarmDraft() {
    // The visible field is the truth. `alarmDraftText` normally tracks it through onTextEdited,
    // but a paste or an IME can skip that signal, and then the committed time would be the old one.
    if (alarmInput && alarmInput.text !== root.alarmDraftText)
      root.alarmDraftText = alarmInput.text

    if (root.alarmDraftValid !== "yes")
      return false

    TimerService.setAlarmTime(root.draftToHh24())
    root.resetAlarmDraft()

    return true
  }

  function setMeridiem(pm) {
    root.alarmDraftPm = pm

    if (root.alarmDraftValid === "yes")
      root.commitAlarmDraft()
  }

  // "NEXT: TODAY * 4:00 PM". Armed or ringing: the target the service actually holds.
  // Off: a preview computed from the committed time, never from the half-typed draft.
  // TODAY/TOMORROW always follows the system's local clock, never the Weather city.
  readonly property string alarmNextLabel: {
    if (TimerService.alarmArmed || TimerService.alarmRinging) {
      const parts = String(TimerService.alarmTargetLabel).split(" ")

      if (parts.length === 2) {
        const t = parts[1].split(":")

        return "NEXT: " + parts[0] + " \u00B7 " + root.display12(parseInt(t[0]), t[1])
      }

      return "NEXT: \u2014"
    }

    const p = String(TimerService.alarmTime).split(":")

    if (p.length !== 2 || TimerService.alarmTimeValid !== "yes")
      return "NEXT: \u2014"

    const hh = parseInt(p[0])
    const now = new Date()
    const target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hh, parseInt(p[1]), 0, 0)
    const day = target.getTime() > now.getTime() ? "TODAY" : "TOMORROW"

    return "NEXT: " + day + " \u00B7 " + root.display12(hh, p[1])
  }

  // A schedule change from outside (a restore at startup) refreshes the field, but never
  // while the owner is typing in it.
  Connections {
    target: TimerService

    function onAlarmTimeChanged() {
      if (!alarmInput.activeFocus)
        root.resetAlarmDraft()
    }
  }

  // ------------------------------------------------------------------- shell
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 22

      // -------------------------------------------------------- left: CLOCK
      ColumnLayout {
        id: clockColumn

        // Equal preferredWidth on both columns: with fillWidth alone QtQuick Layouts
        // hands out the surplus in proportion to each column's own content, which made
        // this one 349 px and the timer 296 px. Equal preferences give a real 50:50.
        Layout.preferredWidth: 322
        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        Layout.alignment: Qt.AlignTop
        // The digits' ink has to line up with the TIMER heading's ink in the right column.
        // A 36 px clock box carries more leading than a 16 px heading, so the WHOLE CLOCK
        // group is lifted as one - the group's internal rhythm is untouched.
        Layout.topMargin: -5
        spacing: 8

        Text {
          text: root.timeText
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 22
          font.weight: Font.Bold
        }

        // Ink gaps below are targets measured between RENDERED elements, not read off
        // the margins: a Text carries its own leading inside its box, so these margins
        // are negative on purpose.
        // clock -> date: 19 px (owner's target)
        Text {
          Layout.topMargin: -5
          text: root.dateText
          color: root.secondaryText

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 3
        }

        // date -> week info: 13 px (owner's target 12-14)
        Text {
          Layout.topMargin: -2
          text: root.todayInfo
          color: root.secondaryText
          opacity: 0.75

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize - 1
        }

        // Year progress: 0 % on January 1, 100 % on December 31, so it resets itself
        // when the year rolls over.
        // week info -> year progress: 16 px (owner's target)
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 0
          spacing: 8

          Text {
            text: "" + root.now.getFullYear()
            color: root.secondaryText

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 2
          }

          Rectangle {
            Layout.preferredWidth: 224
            height: 6

            color: Qt.rgba(root.theme.fg.r, root.theme.fg.g, root.theme.fg.b, 0.15)

            Rectangle {
              height: parent.height
              width: parent.width * (root.yearPercent / 100)
              color: root.theme.accent
            }
          }

          Text {
            text: root.yearPercent + "%"
            color: root.theme.fg

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 2
            font.weight: Font.Bold
          }
        }

        // progress bar -> caption: 16 px (owner's target)
        Text {
          Layout.topMargin: 0
          text: root.yearPercent < 50
            ? "Not yet halfway through " + root.now.getFullYear()
            : "More than halfway through " + root.now.getFullYear()
          color: root.secondaryText
          opacity: 0.75

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize - 2
        }
      }

      Rectangle {
        Layout.fillHeight: true
        width: 1
        color: root.secondaryText
        opacity: 0.22
      }

      // -------------------------------------------------------- right: TIMER
      // Order is deliberate: mode, the time itself, the status, the presets, the
      // reminder, then the actions. Controls are sized so the column has a real
      // hierarchy instead of a row of equally small chips.
      ColumnLayout {
        id: timerColumn
        Layout.preferredWidth: 322
        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        Layout.alignment: Qt.AlignTop
        // Spread over the column: with the actions last the content fills the 285 px
        // content area. 13 px overflowed it by 5 px and squeezed a row; 11 px leaves the
        // 5 px of slack that keeps every control at its target size.
        spacing: 11

        Text {
          text: "TIMER"
          color: root.secondaryText

          font.family: root.theme.fontFamily
          font.pixelSize: 16
          font.weight: Font.DemiBold
        }

        RowLayout {
          spacing: 6

          Repeater {
            model: [{ "key": "countdown", "label": "COUNTDOWN" },
                    { "key": "alarm", "label": "ALARM" }]

            delegate: SmallButton {
              required property var modelData

              text: modelData.label
              active: TimerService.mode === modelData.key
              chipHeight: 32
              labelSize: root.theme.fontSize - 1
              hPadding: 12
              onActivated: TimerService.mode = modelData.key
            }
          }

          Item { Layout.fillWidth: true }
        }

        // --------------------------------------------------------- countdown
        ColumnLayout {
          visible: TimerService.mode === "countdown"
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Running or paused: the remaining time, HH:MM:SS, not editable. The FIXED
            // width (equal to the duration field's below) is what keeps the status slot's
            // start x identical whether the display or the input is showing.
            Text {
              visible: TimerService.running || TimerService.cdStatus === "paused"
              Layout.preferredWidth: 170
              Layout.alignment: Qt.AlignVCenter
              text: TimerService.cdText
              color: root.theme.fg

              font.family: root.theme.fontFamily
              font.pixelSize: 32
              font.weight: Font.Medium
            }

            // Idle or finished: the typed duration, one field, HH:MM:SS.
            TextInput {
              id: durationInput

              visible: !(TimerService.running || TimerService.cdStatus === "paused")
              Layout.preferredWidth: 170
              Layout.alignment: Qt.AlignVCenter

              color: TimerService.cdInputValid ? root.theme.fg : root.theme.warning
              selectionColor: root.theme.accent
              selectByMouse: true
              clip: true

              font.family: root.theme.fontFamily
              font.pixelSize: 32
              font.weight: Font.Medium

              // A live binding, not a one-shot assignment: presets and RESET change
              // TimerService.cdInput and the field has to show that immediately.
              text: TimerService.cdInput

              // Live, so an invalid entry is visible while it is being typed.
              onTextEdited: TimerService.setDurationInput(text)
              onAccepted: TimerService.start()
              onEditingFinished: TimerService.setDurationInput(text)

              Keys.onEscapePressed: {
                text = TimerService.cdInput
                focus = false
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.bottom
                height: 2
                color: TimerService.cdInputValid ? root.theme.accent : root.theme.warning
              }
            }

            // Status sits to the RIGHT of the countdown number, vertically centred on the
            // digits, inside a FIXED 112 px slot whose text is left-aligned: the label
            // (READY / RUNNING / PAUSED / FINISHED) changes without moving the anchor.
            Text {
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredWidth: 112
              text: TimerService.cdStatusLabel
              color: root.theme.fg
              opacity: TimerService.cdStatus === "idle" ? 0.7 : 0.85
              horizontalAlignment: Text.AlignLeft

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize + 6
              font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }
          }

          // Presets: exactly 3 / 5 / 10 minutes, ONE left-aligned group with a plain
          // 11 px gap - no space-between spreading. They fill the duration field, which
          // stays the one place a custom HH:MM:SS is typed.
          RowLayout {
            Layout.fillWidth: true
            spacing: 11

            SmallButton {
              text: "3:00"
              active: TimerService.cdInput === "00:03:00"
              chipHeight: 32
              labelSize: root.theme.fontSize - 1
              hPadding: 12
              onActivated: TimerService.setPreset(180000)
            }

            SmallButton {
              text: "5:00"
              active: TimerService.cdInput === "00:05:00"
              chipHeight: 32
              labelSize: root.theme.fontSize - 1
              hPadding: 12
              onActivated: TimerService.setPreset(300000)
            }

            SmallButton {
              text: "10:00"
              active: TimerService.cdInput === "00:10:00"
              chipHeight: 32
              labelSize: root.theme.fontSize - 1
              hPadding: 12
              onActivated: TimerService.setPreset(600000)
            }

            Item { Layout.fillWidth: true }
          }

          Item { Layout.fillWidth: true }
        }

        // ------------------------------------------------------------- alarm
        ColumnLayout {
          visible: TimerService.mode === "alarm"
          Layout.fillWidth: true
          // Vertical order: time + status, then the NEXT target row, then the shared
          // action row (a SIBLING of this block, hence the bottom margin). The spacing
          // between the time row and the NEXT row is 13 px (owner's 12-16 target) measured
          // box to box; the 14-18 px gap to the buttons comes from this block's 4 px bottom
          // margin plus the column's own 11 px spacing. No bottom anchoring.
          Layout.bottomMargin: 4
          spacing: 13

          RowLayout {
            Layout.fillWidth: true
            // Per-item margins instead of one row spacing: the gaps are different on
            // purpose (20 px from the time to the status, 11 px from the status to the
            // detail) and both are measured from the VISIBLE text edges.
            spacing: 0

            // The whole time CONTROL - HH:MM field plus AM/PM selector - inside ONE fixed
            // width Item. A bare TextInput in a Layout keeps being widened to its implicit
            // size (Layout.maximumWidth does not win), so the field is given an explicit
            // width and the Item pins itself with implicitWidth + Layout.preferredWidth.
            // Measured HH:MM advance at 32 px is 96 px for five glyphs (19.2 px each), so the
            // field is 104 px - the first digit must never clip - then a 6 px gap, then two
            // 25 px meridiem cells = 160 px for the whole control.
            Item {
              id: alarmTimeControl
              Layout.preferredWidth: 160
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: 160
              implicitHeight: Math.max(alarmInput.implicitHeight, meridiemRow.height)

              TextInput {
                id: alarmInput
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 104

                color: root.alarmDraftValid === "yes" ? root.theme.fg : root.theme.warning
                selectionColor: root.theme.accent
                selectByMouse: true
                clip: true

                font.family: root.theme.fontFamily
                font.pixelSize: 32
                font.weight: Font.Medium

                Component.onCompleted: root.resetAlarmDraft()

                onTextEdited: root.alarmDraftText = text
                onAccepted: root.commitAlarmDraft()
                onEditingFinished: root.commitAlarmDraft()

                Keys.onEscapePressed: {
                  root.resetAlarmDraft()
                  focus = false
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.bottom
                  height: 2
                  color: root.alarmDraftValid === "yes" ? root.theme.accent : root.theme.warning
                }
              }

              // AM/PM selector: reads as part of the time control (it sits flush beside the
              // digits), the active cell filled with the accent. Clicking a cell commits
              // immediately - an explicit choice, unlike a half-typed time.
              Row {
                id: meridiemRow
                anchors.left: alarmInput.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                  model: ["AM", "PM"]

                  Rectangle {
                    width: 25
                    height: 22
                    color: (modelData === "PM") === root.alarmDraftPm
                      ? root.theme.accent : "transparent"
                    border.width: 1
                    border.color: (modelData === "PM") === root.alarmDraftPm
                      ? root.theme.accent : root.secondaryText

                    Text {
                      anchors.centerIn: parent
                      text: modelData
                      color: (modelData === "PM") === root.alarmDraftPm
                        ? root.theme.bg : root.secondaryText

                      font.family: root.theme.fontFamily
                      font.pixelSize: root.theme.fontSize - 2
                      font.weight: Font.Bold
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setMeridiem(modelData === "PM")
                    }
                  }
                }
              }
            }

            // Main status: fixed 112 px slot, 20 px, left aligned, 18 px after the right
            // edge of the WHOLE time control (selector included) - the owner's 18-22 px
            // band. The fixed slot keeps its start stable across ALARM OFF / ARMED / RINGING.
            Text {
              id: alarmStatusText
              Layout.alignment: Qt.AlignVCenter
              Layout.leftMargin: 18
              Layout.preferredWidth: 112
              text: TimerService.alarmRinging ? "RINGING"
                : TimerService.alarmArmed ? "ARMED" : "ALARM OFF"
              color: root.theme.fg
              opacity: TimerService.alarmRinging || TimerService.alarmArmed ? 0.85 : 0.7
              horizontalAlignment: Text.AlignLeft

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize + 6
              font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }
          }

          // NEXT: the target detail has its OWN row under the time+status, at a fixed height
          // in every state (OFF / ARMED / RINGING) so the action below never jumps. It reads
          // the COMMITTED schedule, so typing does not move it and an invalid field leaves
          // the last valid target standing. Secondary, muted cream, "NEXT:" makes clear it
          // is a preview of the next target rather than a sign the alarm is on.
          Item {
            id: alarmNextRow
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            Text {
              id: alarmNextText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.alarmNextLabel
              color: root.theme.fg
              opacity: 0.7

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize - 1
              font.weight: Font.DemiBold
            }
          }
        }

          // ---------------------------------------------------------- actions
          // Last on purpose, and deliberately as wide as the content area instead of
          // hugging its labels: the primary action takes the larger share, the secondary
          // the rest. Both modes share this row; one pair is visible at a time.
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SmallButton {
              visible: TimerService.mode === "countdown"
              text: TimerService.running ? "PAUSE"
                : TimerService.cdStatus === "paused" ? "RESUME" : "START"
              active: TimerService.running
              primary: true
              chipHeight: 36
              labelSize: root.theme.fontSize
              hPadding: 20
              Layout.fillWidth: true
              Layout.preferredWidth: 210
              onActivated: TimerService.toggleRunning()
            }

            SmallButton {
              visible: TimerService.mode === "countdown"
              text: "RESET"
              chipHeight: 36
              labelSize: root.theme.fontSize
              hPadding: 16
              Layout.fillWidth: true
              Layout.preferredWidth: 110
              onActivated: TimerService.resetCountdown()
            }

            SmallButton {
              visible: TimerService.mode === "alarm"
              text: TimerService.alarmArmed ? "DISABLE ALARM" : "ENABLE ALARM"
              active: TimerService.alarmArmed
              primary: true
              chipHeight: 36
              labelSize: root.theme.fontSize
              hPadding: 20
              Layout.fillWidth: true
              Layout.preferredWidth: 210
              onActivated: {
                // Disabling never needs a commit; enabling always uses what is on screen, and
                // refuses to arm a half-typed time instead of arming the old one.
                if (TimerService.alarmArmed) {
                  TimerService.toggleAlarm()
                  return
                }

                if (!root.commitAlarmDraft())
                  return

                TimerService.toggleAlarm()
              }
            }

            SmallButton {
              visible: TimerService.mode === "alarm" && TimerService.alarmRinging
              text: "DISMISS ALARM"
              active: true
              chipHeight: 36
              labelSize: root.theme.fontSize
              hPadding: 16
              Layout.fillWidth: true
              Layout.preferredWidth: 160
              onActivated: TimerService.dismissAlarm()
            }
          }
        }
      }
    }

  // ------------------------------------------------------------------ pieces
  // Clickable chip: one component for every button in the tab, so the sizes stay a
  // system instead of drifting per call site. `primary` marks the main action, `active`
  // the currently selected state; hover raises the accent so it reads as clickable with
  // no animation.
  component SmallButton: Rectangle {
    id: smallButton

    property string text: ""
    property bool active: false
    property bool primary: false
    property int chipHeight: 20
    property int labelSize: root.theme.fontSize - 3
    property int hPadding: 14

    signal activated()

    implicitWidth: smallLabel.implicitWidth + smallButton.hPadding * 2
    implicitHeight: smallButton.chipHeight

    color: smallButton.active || smallButton.primary || smallHover.hovered
      ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b,
                smallButton.active || smallButton.primary ? 0.22 : 0.14)
      : "transparent"
    border.width: 1
    border.color: smallButton.active || smallButton.primary || smallHover.hovered
      ? root.theme.accent : root.secondaryText
    radius: 0

    Text {
      id: smallLabel

      anchors.centerIn: parent

      text: smallButton.text
      color: smallButton.active || smallButton.primary || smallHover.hovered
        ? root.theme.accent : root.secondaryText

      font.family: root.theme.fontFamily
      font.pixelSize: smallButton.labelSize
      font.weight: Font.DemiBold
    }

    HoverHandler {
      id: smallHover
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton
      onTapped: smallButton.activated()
    }
  }
}
