import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"

Item {
    id: root

    required property var screen

    readonly property Theme theme: Theme {}

    implicitWidth: wsRow.implicitWidth
    implicitHeight: theme.barHeight

    property var visibleWorkspaces: {
        if (!root.screen)
            return [];

        const outputName = root.screen.name;

        const result = NiriWorkspaces.workspaces.filter(
            function (workspace) {
                return workspace.output === outputName;
            }
        );

        result.sort(
            function (a, b) {
                return a.idx - b.idx;
            }
        );

        return result;
    }

    RowLayout {
        id: wsRow

        anchors.centerIn: parent
        spacing: 14

        Repeater {
            model: root.visibleWorkspaces

            delegate: Item {
                required property var modelData

                implicitWidth: wsText.implicitWidth + 2
                implicitHeight: root.theme.barHeight

                Text {
                    id: wsText

                    anchors.centerIn: parent

                    text: String(modelData.idx)

                    color: modelData.is_active
                        ? root.theme.accent
                        : root.theme.muted

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Bold

                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        NiriWorkspaces.focusWorkspace(modelData)
                    }
                }
            }
        }
    }
}
