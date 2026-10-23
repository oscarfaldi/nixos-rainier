import QtQuick
import QtQuick.Shapes
import "../theme"

// A 270-degree dial, used by the network panel's speed test.
//
// Deliberately flat: thin strokes, square caps, no gradient, no glow - it has to look like the rest
// of this desktop while still reading as a tachometer at a glance. The needle and the value arc
// follow `value` through a short animation, so a live measurement looks alive instead of jumping
// between digits.
Item {
  id: root

  readonly property Theme theme: Theme {}
  // Theme has no secondary token; every popup in this shell carries the same local constant.
  readonly property color secondaryText: "#bdae93"

  // Current reading in Mbps and the end of the scale.
  property real value: 0
  property real fullScale: 1000

  property string label: ""
  // True while this gauge is the one currently being measured, so the arc can take the accent.
  property bool live: false

  readonly property real fraction: {
    if (!(root.fullScale > 0))
      return 0

    return Math.max(0, Math.min(1, root.value / root.fullScale))
  }

  // 0 degrees = 3 o'clock, increasing clockwise: a 270 degree dial opens at the bottom.
  readonly property real startAngle: 135
  readonly property real sweepAngle: 270

  readonly property real strokeWidth: 3
  readonly property real needleLength: Math.min(width, height) / 2 - 10

  // Driven straight from `fraction`; the Behavior makes the arc and needle glide to a new reading
  // instead of snapping between samples.
  property real shownFraction: root.fraction

  Behavior on shownFraction {
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  implicitWidth: 116
  implicitHeight: 132

  Shape {
    id: track

    width: 116
    height: 116

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: root.strokeWidth
      strokeColor: root.theme.muted
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap

      PathAngleArc {
        centerX: track.width / 2
        centerY: track.height / 2
        radiusX: track.width / 2 - root.strokeWidth
        radiusY: track.height / 2 - root.strokeWidth
        startAngle: root.startAngle
        sweepAngle: root.sweepAngle
      }
    }
  }

  Shape {
    id: valueArc

    width: 116
    height: 116

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: root.strokeWidth
      strokeColor: root.live ? root.theme.accent : root.theme.fg
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap

      PathAngleArc {
        centerX: valueArc.width / 2
        centerY: valueArc.height / 2
        radiusX: valueArc.width / 2 - root.strokeWidth
        radiusY: valueArc.height / 2 - root.strokeWidth
        startAngle: root.startAngle
        sweepAngle: root.sweepAngle * root.shownFraction
      }
    }
  }

  // Needle: a straight line from the hub to the arc.
  Shape {
    id: needle

    width: 116
    height: 116

    preferredRendererType: Shape.CurveRenderer

    readonly property real angle: (root.startAngle + root.sweepAngle * root.shownFraction) * Math.PI / 180

    ShapePath {
      strokeWidth: 2
      strokeColor: root.theme.fg
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap

      startX: needle.width / 2
      startY: needle.height / 2

      PathLine {
        x: needle.width / 2 + Math.cos(needle.angle) * root.needleLength
        y: needle.height / 2 + Math.sin(needle.angle) * root.needleLength
      }
    }
  }

  Rectangle {
    anchors.centerIn: needle
    width: 5
    height: 5

    color: root.theme.fg
  }

  Text {
    anchors.horizontalCenter: needle.horizontalCenter
    anchors.top: needle.verticalCenter
    anchors.topMargin: 16

    text: root.value > 0 ? root.value.toFixed(0) : "--"
    color: root.theme.fg

    font.family: root.theme.fontFamily
    font.pixelSize: root.theme.fontSize + 6
    font.weight: Font.Bold
  }

  Text {
    anchors.horizontalCenter: needle.horizontalCenter
    anchors.top: needle.verticalCenter
    anchors.topMargin: 36

    text: "Mbps"
    color: root.secondaryText

    font.family: root.theme.fontFamily
    font.pixelSize: root.theme.fontSize - 3
  }

  Text {
    anchors.horizontalCenter: needle.horizontalCenter
    anchors.top: needle.bottom
    anchors.topMargin: 4

    text: root.label
    color: root.live ? root.theme.accent : root.secondaryText

    font.family: root.theme.fontFamily
    font.pixelSize: root.theme.fontSize - 2
    font.weight: Font.Bold
  }
}
