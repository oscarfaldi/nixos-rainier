import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"
import "../popups"
import "modules"

// Center group of the bar: the date, the time and the weather, each its own click
// target, plus the ONE popup they all open (ShellPopup, three tabs).
//
// The clock (date + time) is anchored to the window's exact horizontalCenter and the
// weather segment hangs off the clock - never the other way around, and never a
// fill-width spacer. An earlier design centred the whole row, which shifted the clock
// whenever the weather text changed length; the owner treats a clock that is not dead
// center as a broken bar.
Item {
  id: root

  // The bar's screen, passed by Bar.qml.
  required property var screen

  readonly property Theme theme: Theme {}
  readonly property string screenName: root.screen ? root.screen.name : ""

  implicitWidth: clock.implicitWidth + weatherLabel.implicitWidth
  implicitHeight: theme.barHeight

  Clock {
    id: clock

    screen: root.screen

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
  }

  // Countdown / alarm readout: inside the centre group, DIRECTLY right of the clock, with its own
  // "|" separators - the weather stays the rightmost segment and shifts right while the readout is
  // visible. Positioned by x, not anchored, and Center's implicitWidth deliberately does NOT
  // include it: Center's width is what keeps the clock dead centre, so the readout must never
  // widen the group.
  TimerIndicator {
    id: readout

    screen: root.screen

    x: clock.x + clock.width
    anchors.verticalCenter: parent.verticalCenter
  }

  WeatherLabel {
    id: weatherLabel

    screen: root.screen

    // readout.width is 0 while nothing is active, so the weather falls back to clock.right.
    anchors.left: readout.right
    anchors.verticalCenter: parent.verticalCenter
  }

  // One popup instance per screen, shared by all three segments: the segment only
  // decides which TAB it opens on. PopupManager keeps exactly one active name, so
  // opening any segment closes whatever else was open.
  ShellPopup {
    screen: root.screen

    visible: PopupManager.isOpen(root.screenName, "popup")

    // The slot the click shield must leave open tracks the popup while it is the active
    // one, so clicks right next to it close it instead of falling into a dead zone.
    // `true` = the popup is centered under the bar, not pinned to an edge.
    onVisibleChanged: {
      if (visible)
        PopupManager.claimSlot(width, height, true)
    }
  }
}
