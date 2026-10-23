import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"

// Power management panel: exactly TWO idle controls, nothing else.
//
//   SCREEN OFF AFTER - when the display turns off (the system keeps running)
//   SLEEP AFTER IDLE - when an idle machine suspends (never a shutdown)
//
// Shape follows the content: two stacked sections, no description lines, in one compact
// panel (320x264). The chips are scaled up as CONTAINERS - 34 px high, 31 px of inner
// padding, 10 px apart - while the text inside them stays on the theme's font token, which
// is what keeps the panel consistent with the rest of the shell.
//
// Square corners, flat surfaces, chips at their natural width in one left-aligned group,
// theme tokens only (AGENTS.md).
//
// NOTE: no `screen` property here on purpose. PanelWindow already carries the layer-shell
// `screen`; declaring it shadows the C++ property and the surface then never maps. The bar
// passes `screen:` at the instantiation site.
PanelWindow {
  id: root

    // Opened state, driven by the bar module (was the window's own `visible`).
    property bool open: false

  readonly property Theme theme: Theme { }

  // Gruvbox light4. Same value as the other panels so every popup shares one text
  // hierarchy.
  readonly property color secondaryText: "#bdae93"

  // Container metrics, scaled ~30% up from the first two-control version (chip 26 -> 34,
  // padding 24 -> 31, gaps 8 -> 10, panel padding 18 -> 23) so the choices are easy to hit
  // and read. Fonts are NOT scaled here: they come from Theme.
  readonly property int chipHeight: 34
  readonly property int chipPadding: 31
  readonly property int chipSpacing: 10
  readonly property int sectionHeight: 63

  exclusionMode: ExclusionMode.Ignore

  // Keyboard focus while open: Escape has to reach this surface, and a
  // grab-free surface would send the key to the app underneath instead.
  // Pre-mapped: the surface stays mapped and only opacity / input region / keyboard focus change,
  // so opening costs no surface creation (~180 ms measured on demand). An empty mask means zero
  // input while closed: the pointer behaves exactly like an unmapped panel.
  visible: true

  mask: Region {
    item: root.open ? frame : null
  }

  WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive
  : WlrKeyboardFocus.None

  anchors.top: true
  anchors.right: true
  margins.top: root.theme.popupTop
  margins.right: root.theme.margins

  color: "transparent"

  implicitWidth: 320
  implicitHeight: 270

  Rectangle {

    id: frame
      opacity: root.open ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: root.theme.duration(root.theme.motion)
          easing.type: Easing.OutCubic
        }
      }


    anchors.fill: parent

    color: root.theme.panel
    border.width: 2
    border.color: root.theme.accent
    radius: 0

    ColumnLayout {
      anchors.fill: parent
      // Explicit margins, not `anchors.margins`: on this layout the shortcut did not hold
      // (measured 17 px side padding against 23 px top/bottom). Explicit is also what the
      // other panels use.
      anchors.leftMargin: 23
      anchors.rightMargin: 23
      anchors.topMargin: 23
      anchors.bottomMargin: 23
      spacing: 0

      // -------------------------------------------------------------- 1. header
      RowLayout {
        id: headerRow

        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        Layout.preferredHeight: 31
        spacing: 13

        Text {
          // Font Awesome crescent (U+F186): idle/sleep policy, not a battery gauge and not
          // a CPU profile. Built with String.fromCodePoint because a "\uXXXX" escape takes
          // exactly four hex digits.
          text: String.fromCodePoint(0xF186)
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 3
          font.weight: Font.Bold

          Layout.alignment: Qt.AlignVCenter
        }

        Text {
          text: "POWER MANAGEMENT"
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 3
          font.weight: Font.Bold

          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.alignment: Qt.AlignVCenter
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 13
        height: 1

        color: root.secondaryText
        opacity: 0.35
      }

      // --------------------------------------------------- 2. screen off after
      // Display only: the compositor powers the monitors off and the rest of the machine
      // keeps working, which is what makes long encodes and downloads survive it.
      ColumnLayout {
        id: displaySection

        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        Layout.preferredHeight: root.sectionHeight
        Layout.topMargin: 16
        spacing: 0

        Text {
          text: "SCREEN OFF AFTER"
          // Foreground, not secondaryText: the section headings carry the same brightness
          // as the panel title, one clear step above the chip text.
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 1
          font.weight: Font.Bold
        }

        RowLayout {
          Layout.topMargin: 8
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.preferredHeight: root.chipHeight
          spacing: root.chipSpacing

          Repeater {
            id: displayChips

            model: PowerService.displayOptions

            delegate: Chip {
              required property var modelData

              label: modelData.label
              active: PowerService.displayMinutes === modelData.key

              onTriggered: PowerService.setDisplay(modelData.key)
            }
          }

          // Keeps the presets one tight, left-aligned group instead of stretching them
          // across the panel.
          Item {
            Layout.fillWidth: true
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 18
        height: 1

        color: root.secondaryText
        opacity: 0.35
      }

      // ---------------------------------------------------- 3. sleep after idle
      ColumnLayout {
        id: suspendSection

        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        Layout.preferredHeight: root.sectionHeight
        Layout.topMargin: 18
        spacing: 0

        Text {
          text: "SLEEP AFTER IDLE"
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 1
          font.weight: Font.Bold
        }

        RowLayout {
          Layout.topMargin: 8
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.preferredHeight: root.chipHeight
          spacing: root.chipSpacing

          Repeater {
            id: suspendChips

            model: PowerService.autoSuspendOptions

            delegate: Chip {
              required property var modelData

              label: modelData.label
              active: PowerService.autoSuspendMinutes === modelData.key

              onTriggered: PowerService.setAutoSuspend(modelData.key)
            }
          }

          Item {
            Layout.fillWidth: true
          }
        }
      }
    }
  }

  // -------------------------------------------------------------------- chip
  // One look for every choice: square, flat, 1px resting border and a 2px accent border
  // while it is the selected value or hovered. No pills, no toggles, no rounded cards.

  component Chip: Rectangle {
    id: chip

    property string label: ""
    property bool active: false

    signal triggered()

    implicitWidth: Math.max(55, chipText.implicitWidth + root.chipPadding)
    implicitHeight: root.chipHeight

    color: "transparent"
    radius: 0

    border.width: 1
    border.color: chip.active || chipHover.hovered ? root.theme.accent : root.secondaryText

    // No whole-chip opacity: it dimmed the label as well, and the label has to stay as
    // bright as the panel title. The state is carried by the border (accent, 2px) and the
    // faint accent fill only.

    Layout.alignment: Qt.AlignVCenter

    Rectangle {
      anchors.fill: parent

      color: root.theme.accent
      opacity: chip.active ? 0.10 : (chipHover.hovered ? 0.06 : 0)

      Behavior on opacity {
        NumberAnimation {
          duration: 120
        }
      }
    }

    Text {
      id: chipText

      anchors.centerIn: parent

      text: chip.label
      color: root.theme.fg

      font.family: root.theme.fontFamily
      // The theme's own body size (not an offset): the chip is the value the owner reads at
      // a glance, and this is still a Theme token - never a hardcoded pixel size.
      font.pixelSize: root.theme.fontSize
      font.weight: Font.DemiBold
    }

    HoverHandler {
      id: chipHover

      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      acceptedButtons: Qt.LeftButton

      onTapped: chip.triggered()
    }
  }

  PopupKeys {
    active: root.open
  }
}
