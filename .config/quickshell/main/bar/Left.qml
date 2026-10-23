import QtQuick
import QtQuick.Layouts
import "../theme"
import "modules"

Item {
    id: root

    required property var screen

    readonly property Theme theme: Theme {}

    implicitWidth: leftRow.implicitWidth
    implicitHeight: theme.barHeight

    RowLayout {
        id: leftRow

        anchors.centerIn: parent
        spacing: 0

        Text {
            text: "\uD83D\uDCB0 Oscar Faldi"

            color: theme.fg

            font.family: theme.fontFamily
            font.pixelSize: theme.fontSize
            font.weight: Font.Bold

            leftPadding: 20
            rightPadding: 15

            verticalAlignment: Text.AlignVCenter

            Layout.fillHeight: true
        }

        Workspaces {
            screen: root.screen

            Layout.alignment: Qt.AlignVCenter
        }
    }
}
