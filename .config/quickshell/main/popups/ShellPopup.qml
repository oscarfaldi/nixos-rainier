import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"
import "tabs"

// The bar's single popup: ONE window, ONE size, ONE header, three tabs (DATE, CLOCK,
// WEATHER). The bar's three interactive segments all open this popup and only differ in
// the tab they ask for (PopupManager.payload).
//
// Fixed geometry is deliberate: the popup never resizes per tab, so switching tabs does
// not move the window under the pointer. The content area below the shared header is
// 765 x 253 px, which is exactly what the weather's approved 54:46 split needs
// (389 + 22 + divider + 22 + 331 = 765); the clock's two columns share it 50:50, and the
// calendar centres its 320 px grid inside it.
//
// Tabs are toggled with `visible`, never a StackLayout: QQuickStackLayout::setCurrentIndex
// segfaults on Qt 6.11.2 (see AGENTS.md).
PanelWindow {
  id: root

  readonly property Theme theme: Theme {}
  readonly property color secondaryText: "#bdae93"

  // NOTE: no `screen` property here on purpose. PanelWindow already carries the
  // layer-shell `screen`; redeclaring it (even as `required property var screen`) shadows
  // the C++ property, the surface loses its output and the popup never maps - it stays
  // invisible while its QML still lays out. The bar passes `screen:` at the
  // instantiation site, exactly like the other popups do.
  readonly property string screenName: root.screen ? root.screen.name : ""
  readonly property bool isOpen: PopupManager.isOpen(root.screenName, "popup")

  readonly property var tabs: [
    { key: "date", label: "DATE" },
    { key: "clock", label: "CLOCK" },
    { key: "weather", label: "WEATHER" }
  ]

  readonly property string tab: PopupManager.payload === "" ? "date" : PopupManager.payload
  readonly property string tabTitle: root.tab === "date" ? "DATE"
    : root.tab === "clock" ? "CLOCK" : "WEATHER"

  exclusionMode: ExclusionMode.Ignore

  // Keyboard focus while open: Escape has to reach this surface, and a
  // grab-free surface would send the key to the app underneath instead.
  WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive
  : WlrKeyboardFocus.None

  // Keyboard focus on demand only (the weather tab carries the city field): the popup
  // must never grab the pointer - a pointer grab is what swallows the first click and
  // breaks one-click tab switching.
  focusable: true

  anchors.top: true
  anchors.left: true
  margins.top: root.theme.popupTop
  margins.left: screen ? Math.round((screen.width - width) / 2) : root.theme.margins

  color: "transparent"

  // 805 px: the weather's 54:46 split needs 765 px of content plus the 20 px margins.
  // 376 px: the tallest tab is DATE, whose calendar column needs 276 px of content
  // (weather needs 264). Set as implicit sizes on purpose: this Quickshell version
  // deprecates `width`/`height` on a panel window, and with them the window falls back
  // to the content's implicit size - which for this popup is only the header row, so
  // the panel came out 320 px wide.
  implicitWidth: 805
  implicitHeight: 376

  // ------------------------------------------------------------------- shell
  Rectangle {
    anchors.fill: parent

    color: root.theme.panel
    border.width: 2
    border.color: root.theme.accent
    radius: 0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 12

      // -------------------------------------------------------------- header
      // Shared by all three tabs: the page name on the left, the navigation on the
      // right. Only the content under the rule changes, so the header never moves.
      RowLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        spacing: 8

        Text {
          text: root.tabTitle
          color: root.theme.fg

          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 3
          font.weight: Font.Bold
        }

        Item {
          // Pushes the tab buttons to the right edge of the header.
          Layout.fillWidth: true
        }

        Repeater {
          model: root.tabs

          delegate: Rectangle {
            required property var modelData

            implicitWidth: tabText.implicitWidth + 18
            implicitHeight: 26

            color: "transparent"
            border.width: 2
            border.color: root.tab === modelData.key ? root.theme.accent : "transparent"
            radius: 0

            // Clickable elements dim while hovered, so it is obvious they respond.
            opacity: root.tab === modelData.key || !tabHover.hovered ? 1 : 0.72

            Text {
              id: tabText

              anchors.centerIn: parent

              text: modelData.label
              color: root.tab === modelData.key ? root.theme.accent : root.secondaryText

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize - 1
              font.weight: Font.DemiBold
            }

            HoverHandler {
              id: tabHover
              cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
              acceptedButtons: Qt.LeftButton

              // Switching tabs keeps the popup open; the bar segment is what closes it.
              onTapped: PopupManager.setPayload(modelData.key)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.secondaryText
        opacity: 0.35
      }

      // ------------------------------------------------------------- content
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        DateTab {
          anchors.fill: parent

          activeTab: root.isOpen && root.tab === "date"
        }

        ClockTab {
          anchors.fill: parent

          activeTab: root.isOpen && root.tab === "clock"
        }

        WeatherTab {
          anchors.fill: parent

          activeTab: root.isOpen && root.tab === "weather"
        }
      }
    }
  }

  PopupKeys {
    active: root.visible
  }
}
