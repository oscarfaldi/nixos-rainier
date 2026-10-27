import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"
import "modules"

PanelWindow {
  id: root

  readonly property Theme theme: Theme {}

  anchors {
    top: true
    left: true
    right: true
  }

  margins.top: root.theme.margins
  margins.left: root.theme.margins
  margins.right: root.theme.margins

  implicitHeight: root.theme.barHeight
  exclusiveZone: root.theme.exclusiveZone
  color: root.theme.bgAlpha

  // Plain anchors instead of a RowLayout: the clock is pinned to the
  // window's exact horizontal center and never shifts regardless of how
  // wide the left/right clusters become.
  // Any click on the bar's empty surface closes the open popup. The
  // modules declared below stack above this catcher and get their own taps.
  MouseArea {
    anchors.fill: parent

    onClicked: PopupManager.close(root.screen.name)
  }

  Left {
    screen: root.screen

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
  }

  Center {
    screen: root.screen

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
  }

  Right {
    screen: root.screen

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }
}