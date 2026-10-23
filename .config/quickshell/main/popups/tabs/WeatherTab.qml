import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services
import "../../theme"

// Weather panel: current reading on the left, three-day forecast on the right.
//
// Opened from the weather segment of the bar. No internal DATE/WEATHER tabs any
// more - the bar has one segment per panel, so this panel is only ever the weather.
//
// Left column (389 px): header group (icon + temperature + city in ONE row) then the
// metrics list, which now starts with CONDITION. The condition used to sit on its own
// line under the temperature, which read as an extra header row that did not belong to
// either block (owner's report).
//
// Right column (331 px): the forecast. The 54:46 column split, the divider and the
// footer position are the ones the owner approved earlier and are deliberately kept.
Item {
  id: root

  // TAB of ShellPopup: the popup owns the window, the fixed 805 x 344 size, the shared
  // header and the tab navigation. The popup's content area is 765 px wide, which is
  // exactly the 389 + 22 + divider + 22 + 331 the approved 54:46 split needs.
  property bool activeTab: false

  visible: activeTab

  readonly property Theme theme: Theme {}
  readonly property color secondaryText: "#bdae93"

  property bool editingCity: false
  property int suggestionIndex: -1

  function moveSuggestion(delta) {
    const count = Weather.suggestions.length
    if (count === 0) {
      root.suggestionIndex = -1
      return
    }

    let next = root.suggestionIndex + delta
    if (next < 0)
      next = count - 1
    if (next >= count)
      next = 0

    root.suggestionIndex = next
  }

  Connections {
    target: Weather

    function onSuggestionsChanged() {
      root.suggestionIndex = Weather.suggestions.length > 0 ? 0 : -1
    }
  }

  function relativeUpdate() {
    if (Weather.updatedAt <= 0)
      return "never"

    const minutes = Math.floor((Date.now() - Weather.updatedAt) / 60000)
    if (minutes < 1)
      return "just now"
    if (minutes < 60)
      return minutes + " min ago"

    return Math.floor(minutes / 60) + " h ago"
  }

  function forecastDayName(dateKey) {
    const parts = String(dateKey).split("-")
    if (parts.length !== 3)
      return dateKey

    const day = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
    return ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
            "THURSDAY", "FRIDAY", "SATURDAY"][day.getDay()]
  }

  onActiveTabChanged: {
    if (!activeTab) {
      editingCity = false
      Weather.clearSuggestions()
    }
  }

  // ------------------------------------------------------------------- shell
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 0
    spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 22

        // ------------------------------------------------------- current reading
        ColumnLayout {
          Layout.preferredWidth: 389
          Layout.fillWidth: false
          Layout.alignment: Qt.AlignTop
          spacing: 6

          // 260 px content container, centred in the 389 px column. Only the
          // CONTAINER is centred: inside it the metric labels stay left and the
          // values stay right.
          ColumnLayout {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            spacing: 6

            // Main row: icon, temperature and city share row 0 of a GridLayout, so
            // the icon is centred on the TEMPERATURE and not on the whole block.
            GridLayout {
              Layout.alignment: Qt.AlignHCenter
              columns: 2
              columnSpacing: 14
              rowSpacing: 2

              Text {
                Layout.row: 0
                Layout.column: 0
                Layout.alignment: Qt.AlignVCenter

                text: Weather.icon
                color: root.theme.fg

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 30
              }

              RowLayout {
                Layout.row: 0
                Layout.column: 1
                Layout.alignment: Qt.AlignVCenter
                spacing: 14

                Text {
                  text: Weather.tempText === "" ? "--" : Weather.tempText
                  color: root.theme.fg

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 30
                  font.weight: Font.Bold
                }

                // The city is the way into the city editor: click it.
                Text {
                  id: placeText

                  Layout.alignment: Qt.AlignVCenter
                  visible: !root.editingCity

                  text: Weather.place === "" ? "location from IP" : Weather.place
                  color: placeHover.hovered ? root.theme.accent : root.theme.fg

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 6
                  font.weight: Font.Bold

                  HoverHandler {
                    id: placeHover
                    cursorShape: Qt.PointingHandCursor
                  }

                  TapHandler {
                    acceptedButtons: Qt.LeftButton

                    onTapped: {
                      cityInput.text = Weather.placeName
                      root.editingCity = true
                      Weather.clearSuggestions()
                      cityInput.forceActiveFocus()
                    }
                  }
                }
              }

              Text {
                Layout.row: 1
                Layout.column: 1
                visible: Weather.placeDetail !== "" && !root.editingCity

                text: Weather.placeDetail
                color: root.secondaryText

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize - 2
              }
            }

            // ----------------------------------------------------- city editor
            ColumnLayout {
              visible: root.editingCity
              Layout.fillWidth: true
              Layout.topMargin: 4
              spacing: 4

              TextInput {
                id: cityInput

                Layout.preferredWidth: 240
                Layout.alignment: Qt.AlignLeft

                color: root.theme.fg
                selectionColor: root.theme.accent
                selectByMouse: true
                clip: true

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize + 1

                onTextEdited: suggestTimer.restart()

                onAccepted: {
                  if (Weather.suggestions.length > 0
                      && root.suggestionIndex >= 0
                      && root.suggestionIndex < Weather.suggestions.length) {
                    Weather.chooseSuggestion(Weather.suggestions[root.suggestionIndex])
                  } else if (Weather.suggestions.length > 0) {
                    Weather.chooseSuggestion(Weather.suggestions[0])
                  } else {
                    Weather.setLocation(cityInput.text)
                  }

                  root.editingCity = false
                }

                Keys.onEscapePressed: {
                  Weather.clearSuggestions()
                  root.editingCity = false
                }

                Keys.onDownPressed: root.moveSuggestion(1)
                Keys.onUpPressed: root.moveSuggestion(-1)

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.bottom
                  height: 1
                  color: root.theme.accent
                }
              }

              // Debounced: a fast typist sends one request, not one per keystroke.
              Timer {
                id: suggestTimer

                interval: 320
                running: false
                repeat: false

                onTriggered: Weather.suggest(cityInput.text)
              }

              Text {
                visible: Weather.suggestions.length === 0
                text: "TYPE 2+ LETTERS, THEN \u2191\u2193 + ENTER \u00B7 ESC CANCELS"
                color: root.secondaryText
                opacity: 0.75

                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.fontSize - 4
                font.weight: Font.Bold
              }

              Repeater {
                model: Weather.suggestions

                delegate: Rectangle {
                  required property var modelData
                  required property int index

                  Layout.fillWidth: true
                  implicitHeight: 24

                  color: index === root.suggestionIndex
                    ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.24)
                    : (rowHover.hovered
                        ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.12)
                        : "transparent")
                  radius: 0

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                      text: modelData.name
                      color: index === root.suggestionIndex ? root.theme.accent : root.theme.fg

                      font.family: root.theme.fontFamily
                      font.pixelSize: root.theme.fontSize - 1
                      font.weight: Font.Bold
                    }

                    Text {
                      text: modelData.detail
                      color: root.secondaryText

                      font.family: root.theme.fontFamily
                      font.pixelSize: root.theme.fontSize - 2
                    }

                    Item { Layout.fillWidth: true }
                  }

                  HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                  }

                  TapHandler {
                    acceptedButtons: Qt.LeftButton

                    onTapped: {
                      Weather.chooseSuggestion(modelData)
                      root.editingCity = false
                    }
                  }
                }
              }
            }

            // A faint rule between the header group and the measurements.
            Rectangle {
              visible: !root.editingCity
              Layout.fillWidth: true
              height: 1
              color: root.secondaryText
              opacity: 0.18
            }

            // --------------------------------------------------------- metrics
            // Seven rows now: CONDITION leads the list, so the reading and its
            // condition live in the same block. Hidden while the city editor is
            // open, because a search row plus a suggestion list plus seven rows
            // overflows the fixed panel height.
            Repeater {
              visible: !root.editingCity

              model: [
                { "label": "CONDITION", "value": Weather.current ? Weather.current.desc : "-" },
                { "label": "FEELS LIKE", "value": Weather.current ? Weather.current.feels + "\u00B0" : "-" },
                { "label": "WIND", "value": Weather.current ? Weather.current.wind + " km/h " + Weather.current.windDir : "-" },
                { "label": "HUMIDITY", "value": Weather.current ? Weather.current.humidity + "%" : "-" },
                { "label": "UV INDEX", "value": Weather.current ? Weather.current.uv : "-" },
                { "label": "SUNRISE", "value": Weather.current ? Weather.current.sunrise : "-" },
                { "label": "SUNSET", "value": Weather.current ? Weather.current.sunset : "-" }
              ]

              delegate: RowLayout {
                required property var modelData

                // 260 px cap so a label and its value stay one group instead of
                // sitting at the two ends of the 389 px column. The rows share the
                // leftover height, which is what sets the 26 px pitch.
                Layout.fillWidth: true
                Layout.maximumWidth: 260
                Layout.fillHeight: true
                spacing: 10

                Text {
                  Layout.alignment: Qt.AlignVCenter
                  text: modelData.label
                  color: root.secondaryText

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize - 2
                  font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                Text {
                  Layout.alignment: Qt.AlignVCenter
                  text: modelData.value
                  color: root.theme.fg

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 2
                  font.weight: Font.Bold
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillHeight: true
          width: 1
          color: root.secondaryText
          opacity: 0.22
        }

        // ------------------------------------------------------------ forecast
        ColumnLayout {
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.fillHeight: true
          spacing: 8

          // The heading's visual centre is put on the visual centre of the main
          // temperature/location group in the left column (owner's C1). The group is
          // a row of 57 px; this title is 20 px, so the 18 px top margin lands their
          // centres on the same line - measured, not assumed.
          Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 100000
            Layout.topMargin: 17
            Layout.bottomMargin: 12

            text: "3-DAY FORECAST"
            color: root.theme.fg
            horizontalAlignment: Text.AlignHCenter

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize + 3
            font.weight: Font.DemiBold
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 100000
            spacing: 0

            Repeater {
              model: Weather.forecast

              delegate: ColumnLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.maximumWidth: 100000
                Layout.alignment: Qt.AlignTop
                spacing: 0

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: root.forecastDayName(modelData.date)
                  color: root.secondaryText

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize - 2
                  font.weight: Font.Bold
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  // 7 px as a layout gap lands at a 24-28 px visual gap: the day
                  // Text's leading plus the icon glyph's own padding make up the rest.
                  Layout.topMargin: 7
                  text: Weather.forecastIcon(modelData.code)
                  color: root.theme.fg

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 24
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.topMargin: 10
                  text: modelData.hi + "\u00B0"
                  color: root.theme.fg

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 6
                  font.weight: Font.Bold
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.topMargin: 5
                  text: modelData.lo + "\u00B0"
                  color: root.secondaryText

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 1
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.topMargin: 12
                  text: "RAIN " + modelData.rain + "%"
                  color: modelData.rain >= 50 ? root.theme.accent : root.secondaryText
                  opacity: modelData.rain >= 50 ? 1 : 0.7

                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize - 3
                  font.weight: Font.Bold
                }
              }
            }

            Text {
              visible: Weather.forecast.length === 0
              text: "no forecast yet"
              color: root.secondaryText

              font.family: root.theme.fontFamily
              font.pixelSize: root.theme.fontSize - 2
            }
          }

          // Age of the reading, under the forecast it belongs to. Cream at 80 % keeps
          // it readable; the bottom margin keeps the approved 35-40 px clearance from
          // the border's inner edge.
          Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 100000
            Layout.topMargin: 2
            Layout.bottomMargin: 20
            horizontalAlignment: Text.AlignHCenter
            text: Weather.failed ? "showing the last reading" : "updated " + root.relativeUpdate()
            color: Weather.failed ? root.theme.warning : root.theme.fg
            opacity: 0.8

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 3
          }
        }
      }
    }
}
