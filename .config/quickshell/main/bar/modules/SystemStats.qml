import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"

Item {
  readonly property Theme theme: Theme {}

  implicitWidth: statsRow.implicitWidth
  implicitHeight: root.theme.barHeight

  RowLayout {
    id: statsRow
    anchors.centerIn: parent
    spacing: 20

    // CPU: icon and value kept as one unit
    Text {
      text: " " + SystemStats.cpuUsage.toFixed(0) + "%"
      color: theme.fg
      font.family: theme.fontFamily
      font.pixelSize: theme.fontSize
      font.weight: Font.Bold
      verticalAlignment: Text.AlignVCenter
    }

    // Memory
    Text {
      text: "󰍛 " + SystemStats.memoryUsed.toFixed(1) + "G"
      color: theme.fg
      font.family: theme.fontFamily
      font.pixelSize: theme.fontSize
      font.weight: Font.Bold
      verticalAlignment: Text.AlignVCenter
    }
  }
}