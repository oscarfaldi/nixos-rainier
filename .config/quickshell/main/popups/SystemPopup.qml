import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../theme"

PanelWindow {
    id: root

    // Opened state, driven by the bar module (was the window's own `visible`).
    property bool open: false

    readonly property Theme theme: Theme {}

    // Gruvbox light4. Same value as the other popups so all panels
    // share one text hierarchy.
    readonly property color secondaryText: "#bdae93"

    signal lockRequested()
    signal logoutRequested()
    signal suspendRequested()
    signal restartRequested()
    signal shutdownRequested()

    implicitWidth: 396
    implicitHeight: 450

    // No input grab (plain layer surface): bar clicks keep working while
    // the popup is open. Fixed top-right position, flush with the bar's
    // right edge, 12px below the bar (owner-approved values).
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
    // niri positions layer margins from the SCREEN edge, not from the
    // free area: 48 (bar zone) + 13 (bar margin) + 35 (bar height) + 12
    // (gap) keeps the panel below the bar without covering it.
    margins.top: root.theme.popupTop
    margins.right: root.theme.margins

    color: "transparent"


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
            // Owner's targets, measured box to box, scaled ~10% for visibility: 18 px
            // panel padding, 10 px from the header rule to the first card and between
            // cards, 14 px either side of the divider; the leftover height stays as bottom
            // air (no spacer, nothing pushed down).
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 18
            anchors.bottomMargin: 18
            spacing: 0

            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: ""
                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 3
                    font.weight: Font.Bold
                }

                Text {
                    text: "SYSTEM"
                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 3
                    font.weight: Font.Bold

                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            // --------------------------------------------------
            // POWER
            // --------------------------------------------------

            SystemButton {
                Layout.fillWidth: true

                icon: ""
                Layout.topMargin: 10
                title: "SUSPEND"
                subtitle: "Sleep computer"

                onClicked: root.suspendRequested()
            }

            SystemButton {
                Layout.fillWidth: true

                icon: ""
                Layout.topMargin: 10
                title: "RESTART"
                subtitle: "Restart computer"

                onClicked: root.restartRequested()
            }

            SystemButton {
                Layout.fillWidth: true

                icon: ""
                Layout.topMargin: 10
                title: "SHUTDOWN"
                subtitle: "Power off computer"

                onClicked: root.shutdownRequested()
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.22

                Layout.topMargin: 14
            }

            // --------------------------------------------------
            // SESSION
            // --------------------------------------------------

            SystemButton {
                Layout.fillWidth: true

                icon: ""
                Layout.topMargin: 14
                title: "LOCK SCREEN"
                subtitle: "Lock current session"

                onClicked: root.lockRequested()
            }

            SystemButton {
                Layout.fillWidth: true

                icon: ""
                Layout.topMargin: 10
                title: "LOGOUT"
                subtitle: "End Niri session"

                onClicked: root.logoutRequested()
            }

        }
    }

    // --------------------------------------------------
    // SHARED BUTTON STYLE
    // --------------------------------------------------

    component SystemButton: Rectangle {
        id: button

        property string icon: ""
        property string title: ""
        property string subtitle: ""

        signal clicked()

        implicitHeight: 62

        color: "transparent"

        border.width: 1
        border.color:
            hover.hovered
                ? root.theme.accent
                : root.secondaryText

        radius: 0

        Rectangle {
            anchors.fill: parent

            color: root.theme.accent

            opacity: hover.hovered ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        RowLayout {
            anchors.fill: parent

            anchors.leftMargin: 12
            anchors.rightMargin: 12

            spacing: 10

            Text {
                text: button.icon

                color:
                    hover.hovered
                        ? root.theme.accent
                        : root.theme.fg

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 3
                font.weight: Font.Bold

                Layout.preferredWidth: 30
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: button.title

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Bold

                    Layout.fillWidth: true
                }

                Text {
                    text: button.subtitle

                    color: root.secondaryText

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize - 2

                    Layout.fillWidth: true
                }
            }

            Text {
                text: "›"

                color:
                    hover.hovered
                        ? root.theme.accent
                        : root.secondaryText

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 3
                font.weight: Font.Bold
            }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton

            onTapped: {
                button.clicked()
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
    }

  PopupKeys {
    active: root.open
  }
}
