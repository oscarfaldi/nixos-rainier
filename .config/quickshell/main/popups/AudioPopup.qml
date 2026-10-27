import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../theme"

PanelWindow {
    id: root

    // Opened state, driven by the bar module (was the window's own `visible`).
    property bool open: false

    readonly property Theme theme: Theme {}

    // Match the secondary text treatment used by NetworkPopup.
    readonly property color secondaryText: "#bdae93"

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

    width: 420
    // Height follows the content (18 px margins + the 2 px frame): no dead space at the bottom when
    // fewer devices are present.
    height: Math.ceil(mainColumn.implicitHeight) + 40


    // --------------------------------------------------
    // POSITION
    // --------------------------------------------------


    // --------------------------------------------------
    // PIPEWIRE
    // --------------------------------------------------

    readonly property var audioNodes:
        Pipewire.nodes.values.filter(
            node => node.audio !== null
        )

    readonly property var outputNodes:
        root.audioNodes.filter(
            node => node.isSink && !node.isStream
        )

    readonly property var inputNodes:
        root.audioNodes.filter(
            node => node.isSource && !node.isStream
        )

    readonly property var outputNode:
        Pipewire.defaultAudioSink

    readonly property var inputNode:
        Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: root.audioNodes
    }

    // --------------------------------------------------
    // HELPERS
    // --------------------------------------------------

    function nodeName(node) {
        if (!node)
            return "Unknown device"

        if (node.nickname && node.nickname.length > 0)
            return node.nickname

        if (node.description && node.description.length > 0)
            return node.description

        return node.name || "Unknown device"
    }

    function setVolume(node, value) {
        if (!node || !node.audio)
            return

        node.audio.volume = Math.max(
            0,
            Math.min(1, value)
        )
    }

    function adjustVolume(node, amount) {
        if (!node || !node.audio)
            return

        setVolume(
            node,
            node.audio.volume + amount
        )
    }

    function toggleMute(node) {
        if (!node || !node.audio)
            return

        node.audio.muted = !node.audio.muted
    }

    // --------------------------------------------------
    // MAIN CONTAINER
    // --------------------------------------------------

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
            id: mainColumn

            anchors.fill: parent
            anchors.margins: 18

            spacing: 10

            // ==================================================
            // HEADER
            // ==================================================

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "  AUDIO"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 3
                    font.weight: Font.Bold

                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }


            // ==================================================
            // OUTPUT
            // ==================================================

            Text {
                text: "OUTPUT"

                color: root.theme.accent

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 2
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            // Current output
            RowLayout {
                Layout.fillWidth: true

                spacing: 10

                Text {
                    text: "󰕾"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 3
                    font.weight: Font.Bold
                }

                Text {
                    text: root.outputNode
                        ? root.nodeName(root.outputNode)
                        : "No output"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 1
                    font.weight: Font.Bold

                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            // --------------------------------------------------
            // OUTPUT CONTROLS
            // --------------------------------------------------

            Item {
                Layout.fillWidth: true
                implicitHeight: outputStack.implicitHeight

                // Volume and meter are stacked on the left; the mute chip on the right spans BOTH
                // rows, so it is centred against the slider and the bar at the same time.
                ColumnLayout {
                    id: outputStack

                    anchors.left: parent.left
                    anchors.right: outputMuteButton.left
                    anchors.rightMargin: 15
                    anchors.top: parent.top
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        Item {
                            Layout.fillWidth: true
                            height: 28

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter

                                width: parent.width
                                height: 5

                                color: root.theme.muted
                                opacity: 0.5
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                width:
                                    parent.width *
                                    (
                                        root.outputNode &&
                                        root.outputNode.audio
                                            ? root.outputNode.audio.volume
                                            : 0
                                    )

                                height: 5

                                color: root.theme.accent
                            }

                            Rectangle {
                                width: 11
                                height: 11

                                x:
                                    (
                                        parent.width *
                                        (
                                            root.outputNode &&
                                            root.outputNode.audio
                                                ? root.outputNode.audio.volume
                                                : 0
                                        )
                                    ) - width / 2

                                anchors.verticalCenter: parent.verticalCenter

                                color: root.theme.accent
                            }

                            MouseArea {
                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                // Click / drag
                                onPressed: {
                                    root.setVolume(
                                        root.outputNode,
                                        mouse.x / width
                                    )
                                }

                                onPositionChanged: {
                                    if (pressed) {
                                        root.setVolume(
                                            root.outputNode,
                                            mouse.x / width
                                        )
                                    }
                                }

                                // Scroll = ±5%
                                onWheel: {
                                    if (wheel.angleDelta.y === 0)
                                        return

                                    const amount =
                                        wheel.angleDelta.y > 0
                                            ? 0.05
                                            : -0.05

                                    root.adjustVolume(
                                        root.outputNode,
                                        amount
                                    )

                                    wheel.accepted = true
                                }
                            }
                        }

                        Text {
                            text:
                                root.outputNode && root.outputNode.audio
                                    ? Math.round(root.outputNode.audio.volume * 100) + "%"
                                    : "0%"

                            color: root.theme.fg
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSize
                            font.weight: Font.Bold

                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 36
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        AudioMeter {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            // 48 px kept for the dB readout, which sits right after the bar.
                            reserveRight: 48
                            node: root.outputNode
                            active: root.open
                        }
                    }
                }

                Rectangle {
                    id: outputMuteButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 56


                    color:
                        root.outputNode &&
                        root.outputNode.audio &&
                        root.outputNode.audio.muted
                            ? root.theme.accent
                            : outputMuteHover.hovered
                                ? root.theme.accent
                                : "transparent"

                    opacity: root.outputNode ? 1 : 0.35

                    border.width: 1
                    border.color: root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.outputNode &&
                            root.outputNode.audio &&
                            root.outputNode.audio.muted
                                ? "󰖁"
                                : "󰕾"

                        color: root.theme.fg
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize + 3
                        font.weight: Font.Bold
                    }

                    HoverHandler {
                        id: outputMuteHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.toggleMute(root.outputNode)
                        }
                    }
                }
            }

            // --------------------------------------------------
            // OUTPUT DEVICES
            // --------------------------------------------------

            ListView {
                // Equal breathing room above and below: the list used to sit right on the
                // meter above it. Both margins are 8 px.
                // Section spacing (10 px) already sits above the list, so this margin is what you
                // actually see. Output gets 16/16; input gets 16/8 because the panel's own 18 px
                // margin fills the bottom, which makes both lists read as evenly padded.
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                id: outputList

                Layout.fillWidth: true
                // Follow the content, never taller than 88: with one device the list used to leave
                // an empty band inside the panel.
                Layout.preferredHeight: Math.min(outputList.contentHeight, 88)

                spacing: 5
                clip: true

                model: ScriptModel {
                    values: root.outputNodes
                }

                delegate: Rectangle {
                    id: outputDelegate

                    required property var modelData

                    width: outputList.width
                    height: 40

                    color: "transparent"

                    border.width:
                        modelData === Pipewire.defaultAudioSink
                            ? 2
                            : 1

                    border.color:
                        modelData === Pipewire.defaultAudioSink
                            ? root.theme.accent
                            : root.secondaryText

                    // Active / hover background
                    Rectangle {
                        anchors.fill: parent

                        color: root.theme.accent

                        opacity:
                            modelData === Pipewire.defaultAudioSink
                                ? 0.12
                                : hoverHandler.hovered
                                    ? 0.08
                                    : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        spacing: 10

                        Text {
                            text:
                                modelData === Pipewire.defaultAudioSink
                                    ? "●"
                                    : "○"

                            color:
                                modelData === Pipewire.defaultAudioSink
                                    ? root.theme.fg
                                    : root.theme.muted

                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSize
                        }

                        Text {
                            text: root.nodeName(modelData)

                            color: root.theme.fg

                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSize + 1
                            font.weight: Font.Bold

                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }

                        Text {
                            text:
                                modelData.audio
                                    ? Math.round(
                                        modelData.audio.volume * 100
                                      ) + "%"
                                    : ""

                            color: root.secondaryText

                            font.family: root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize - 1
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            Pipewire.preferredDefaultAudioSink =
                                modelData
                        }
                    }
                }
            }

            // ==================================================
            // INPUT
            // ==================================================

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            Text {
                text: "INPUT"

                color: root.theme.accent

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 2
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1

                color: root.secondaryText
                opacity: 0.35
            }

            // Current input
            RowLayout {
                Layout.fillWidth: true

                spacing: 10

                Text {
                    text: "󰍬"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 3
                    font.weight: Font.Bold
                }

                Text {
                    text: root.inputNode
                        ? root.nodeName(root.inputNode)
                        : "No input"

                    color: root.theme.fg

                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize + 1
                    font.weight: Font.Bold

                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            // --------------------------------------------------
            // INPUT CONTROLS
            // --------------------------------------------------

            Item {
                Layout.fillWidth: true
                implicitHeight: inputStack.implicitHeight

                // Volume and meter are stacked on the left; the mute chip on the right spans BOTH
                // rows, so it is centred against the slider and the bar at the same time.
                ColumnLayout {
                    id: inputStack

                    anchors.left: parent.left
                    anchors.right: inputMuteButton.left
                    anchors.rightMargin: 15
                    anchors.top: parent.top
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        Item {
                            Layout.fillWidth: true
                            height: 28

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter

                                width: parent.width
                                height: 5

                                color: root.theme.muted
                                opacity: 0.5
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                width:
                                    parent.width *
                                    (
                                        root.inputNode &&
                                        root.inputNode.audio
                                            ? root.inputNode.audio.volume
                                            : 0
                                    )

                                height: 5

                                color: root.theme.accent
                            }

                            Rectangle {
                                width: 11
                                height: 11

                                x:
                                    (
                                        parent.width *
                                        (
                                            root.inputNode &&
                                            root.inputNode.audio
                                                ? root.inputNode.audio.volume
                                                : 0
                                        )
                                    ) - width / 2

                                anchors.verticalCenter: parent.verticalCenter

                                color: root.theme.accent
                            }

                            MouseArea {
                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                // Click / drag
                                onPressed: {
                                    root.setVolume(
                                        root.inputNode,
                                        mouse.x / width
                                    )
                                }

                                onPositionChanged: {
                                    if (pressed) {
                                        root.setVolume(
                                            root.inputNode,
                                            mouse.x / width
                                        )
                                    }
                                }

                                // Scroll = ±5%
                                onWheel: {
                                    if (wheel.angleDelta.y === 0)
                                        return

                                    const amount =
                                        wheel.angleDelta.y > 0
                                            ? 0.05
                                            : -0.05

                                    root.adjustVolume(
                                        root.inputNode,
                                        amount
                                    )

                                    wheel.accepted = true
                                }
                            }
                        }

                        Text {
                            text:
                                root.inputNode && root.inputNode.audio
                                    ? Math.round(root.inputNode.audio.volume * 100) + "%"
                                    : "0%"

                            color: root.theme.fg
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSize
                            font.weight: Font.Bold

                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 36
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        AudioMeter {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            // 48 px kept for the dB readout, which sits right after the bar.
                            reserveRight: 48
                            node: root.inputNode
                            active: root.open
                        }
                    }
                }

                Rectangle {
                    id: inputMuteButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 56


                    color:
                        root.inputNode &&
                        root.inputNode.audio &&
                        root.inputNode.audio.muted
                            ? root.theme.accent
                            : inputMuteHover.hovered
                                ? root.theme.accent
                                : "transparent"

                    opacity: root.inputNode ? 1 : 0.35

                    border.width: 1
                    border.color: root.secondaryText

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.inputNode &&
                            root.inputNode.audio &&
                            root.inputNode.audio.muted
                                ? "󰍭"
                                : "󰍬"

                        color: root.theme.fg
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.fontSize + 3
                        font.weight: Font.Bold
                    }

                    HoverHandler {
                        id: inputMuteHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.toggleMute(root.inputNode)
                        }
                    }
                }
            }

            // --------------------------------------------------
            // INPUT DEVICES
            // --------------------------------------------------

            ListView {
                // Equal breathing room above and below: the list used to sit right on the
                // meter above it. Both margins are 8 px.
                // Section spacing (10 px) already sits above the list, so this margin is what you
                // actually see. Output gets 16/16; input gets 16/8 because the panel's own 18 px
                // margin fills the bottom, which makes both lists read as evenly padded.
                Layout.topMargin: 16
                Layout.bottomMargin: 8
                id: inputList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(inputList.contentHeight, 52)

                spacing: 5
                clip: true

                model: ScriptModel {
                    values: root.inputNodes
                }

                delegate: Rectangle {
                    id: inputDelegate

                    required property var modelData

                    width: inputList.width
                    height: 40

                    color: "transparent"

                    border.width:
                        modelData === Pipewire.defaultAudioSource
                            ? 2
                            : 1

                    border.color:
                        modelData === Pipewire.defaultAudioSource
                            ? root.theme.accent
                            : root.secondaryText

                    Rectangle {
                        anchors.fill: parent

                        color: root.theme.accent

                        opacity:
                            modelData === Pipewire.defaultAudioSource
                                ? 0.12
                                : inputHover.hovered
                                    ? 0.08
                                    : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        spacing: 10

                        Text {
                            text:
                                modelData ===
                                Pipewire.defaultAudioSource
                                    ? "●"
                                    : "○"

                            color:
                                modelData ===
                                Pipewire.defaultAudioSource
                                    ? root.theme.fg
                                    : root.theme.muted

                            font.family: root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize
                        }

                        Text {
                            text: root.nodeName(modelData)

                            color: root.theme.fg

                            font.family: root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize
                            font.weight: Font.Bold

                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }

                        Text {
                            text:
                                modelData.audio
                                    ? Math.round(
                                        modelData.audio.volume * 100
                                      ) + "%"
                                    : ""

                            color: root.secondaryText

                            font.family: root.theme.fontFamily
                            font.pixelSize:
                                root.theme.fontSize - 1
                        }
                    }

                    HoverHandler {
                        id: inputHover
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            Pipewire.preferredDefaultAudioSource =
                                modelData
                        }
                    }
                }
            }



        }
    }

  PopupKeys {
    active: root.open
  }
}
