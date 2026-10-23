import Quickshell.Services.Pipewire
import QtQuick
import "../theme"

// Real level meter for one PipeWire node: a sink (what is playing) or a source (the microphone).
//
// Peaks come from Quickshell's own PipeWire client (PwNodePeakMonitor), so there is no ffmpeg, no
// parec and no extra process - the shell is already attached to the graph.
//
// Scale is -36 dBFS (silence) to 0 dBFS (full scale). Segments are coloured by their POSITION on
// the scale, like a mixer strip, so the danger zone is always visible: accent up to -6 dB, warning
// above. The number on the right is the peak HOLD (decays ~5 dB every 800 ms), which is the part
// that answers "is my microphone hot or quiet".
//
// The floor used to be -60 dB and every bar looked wrong because of it: half the bar was spent on
// levels nobody hears, so 5 % volume already filled a quarter of it and the last 20 dB barely moved.
// -36 dB keeps ~two thirds of the bar for the range music actually lives in (-30..-6).
//
// The bar spans `barWidth` exactly so it lines up with the volume slider above it; `reserveRight`
// is the width of the slider row's trail (percent + mute chip) that the dB readout lives under.
Item {
  id: root

  readonly property Theme theme: Theme {}
  readonly property color secondaryText: "#bdae93"

  property var node: null
  // Peak monitoring runs a timer per node, so it is only on while the panel is on screen.
  property bool active: false

  property int segments: 32
  property int reserveRight: 0
  readonly property real minDb: -36

  implicitHeight: 16

  PwNodePeakMonitor {
    id: monitor

    node: root.node
    enabled: root.active && root.node !== null
  }

  readonly property real db: monitor.peak > 0.000001
    ? 20 * Math.log10(monitor.peak)
    : root.minDb

  readonly property real level: Math.max(0, Math.min(1, (root.db - root.minDb) / -root.minDb))

  property real holdDb: root.minDb

  onDbChanged: {
    if (root.db > root.holdDb)
      root.holdDb = root.db
  }

  Timer {
    interval: 800
    repeat: true
    running: root.active

    onTriggered: root.holdDb = Math.max(root.db, root.holdDb - 5)
  }

  Row {
    id: bars

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter

    width: Math.max(0, root.width - root.reserveRight)
    spacing: 2

    Repeater {
      model: root.segments

      Rectangle {
        // Segment i owns the slice [i/segments, (i+1)/segments) of the scale.
        readonly property real segmentDb: root.minDb + (index + 0.5) / root.segments * -root.minDb
        readonly property bool lit: root.level > index / root.segments

        width: Math.max(
          1,
          (bars.width - (root.segments - 1) * bars.spacing) / root.segments
        )
        height: 9

        color: lit
          ? (segmentDb > -6 ? root.theme.warning : root.theme.accent)
          : Qt.rgba(root.theme.muted.r, root.theme.muted.g, root.theme.muted.b, 0.35)
      }
    }
  }

  // Sits immediately after the bar, in the free space under the percent/mute column: reads as
  // "bar -> value" instead of floating under an unrelated control.
  Text {
    anchors.left: bars.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter

    text: root.holdDb <= root.minDb ? "-inf" : root.holdDb.toFixed(0) + " dB"
    color: root.holdDb > -6 ? root.theme.warning : root.secondaryText

    font.family: root.theme.fontFamily
    font.pixelSize: root.theme.fontSize - 2
    font.weight: Font.Bold
  }
}
