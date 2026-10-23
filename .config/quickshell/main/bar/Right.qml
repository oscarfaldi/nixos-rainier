import QtQuick
import QtQuick.Layouts
import "../theme"
import "modules"

Item {
  id: rightGroup

  // The bar's screen, handed down by Bar.qml (an entry of Quickshell.screens).
  // The popup-opening modules need it - see modules/Audio.qml.
  required property var screen

  readonly property Theme theme: Theme {}

  implicitWidth: rightRow.implicitWidth
  implicitHeight: theme.barHeight

  RowLayout {
    id: rightRow
    anchors.centerIn: parent
    // OPTICAL spacing instead of one uniform layout spacing: the right-side
    // glyphs have different ink widths and side bearings (the speaker glyph
    // is much wider than the power circle), so an identical RowLayout spacing
    // still reads as uneven gaps. Each module therefore carries an explicit
    // left margin, calibrated by measuring ink-to-ink gaps in a grim
    // screenshot (target ~22px of visible space between groups).
    spacing: 0

    // cpu + memory: their internal 20px spacing is owner-approved, keep it
    SystemStats { Layout.alignment: Qt.AlignVCenter }
    // ink gap to memory measured 23px -> approved as-is, keep margin 20
    Network {
      screen: rightGroup.screen
      Layout.alignment: Qt.AlignVCenter
      Layout.leftMargin: 20
    }
    // 26px at margin 20: pull the speaker 4px closer to the network label
    Audio {
      screen: rightGroup.screen
      Layout.alignment: Qt.AlignVCenter
      Layout.leftMargin: 16
    }
    // the tray collapses to zero width when nothing is left to show; when it
    // is visible it takes the same optical margin as its neighbours
    Tray        { Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 16 }
    // power management panel: immediately LEFT of the power menu launcher, because the
    // two are the same family of "system" actions (and both panels open flush right,
    // under this end of the bar). Measured ink gaps with this margin: audio -> this 22,
    // this -> power 22 (margin 20 gave 18/26 - the crescent carries less ink than the
    // speaker, so the layout margin is not the visible gap and has to be measured).
    // Measured ink-to-ink on a grim screenshot (icon band only): at 24 the gap to the speaker
    // read 38px while every other group sat at 21/22/20. The crescent glyph keeps ~16px of empty
    // advance on its left, so the margin has to be 16 below the intended gap: 8 gives 22px.
    // These numbers are visible pixels, not layout units - re-measure after touching the icons.
    PowerManagement {
      screen: rightGroup.screen
      Layout.alignment: Qt.AlignVCenter
      // Measured ink gap to the speaker: margin 8 gave 9px, 20 gave 21px - still the tightest pair
      // on the row because the crescent carries very little ink on its left side. 25 lands on ~23px ink.
      Layout.leftMargin: 25
    }
    // the power circle carries a negative left bearing and the crescent before it much
    // less ink than the speaker, so this margin was re-calibrated when the power
    // management icon moved in next door: 21 reads as 22px ink to the crescent on one
    // side and 22px to the speaker chain on the other (25 was right for the speaker).
    // Re-measure after touching any right-side icon: these numbers are ink, not layout values.
    SystemActions {
      screen: rightGroup.screen
      Layout.alignment: Qt.AlignVCenter
      Layout.leftMargin: 21
    }
  }
}