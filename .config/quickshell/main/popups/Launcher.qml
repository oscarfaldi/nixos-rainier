import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"

// Application launcher.
//
// Keyboard-first by design: while the panel is visible the surface holds exclusive keyboard
// focus, the text field owns every key, and the list is derived from that query. An empty query
// shows EVERY application sorted A-Z by name, not by a frecency cache.
//
// Typing scores names with "substring first, then subsequence", so "fir" hits Firefox, "gp" hits
// GIMP and "ter" still hits Ghostty.
//
// Hidden applications come from `main/launcher.hides` (one desktop id per line,
// `#` starts a comment). The same file drives the tombstone .desktop files that Nix generates,
// so every XDG consumer on the machine hides the same set - the list is the only thing to edit.
//
// Square corners, flat surfaces, theme tokens only (AGENTS.md). No animation, no sidebar.
PanelWindow {
  id: root

  readonly property Theme theme: Theme { }

  // Gruvbox light4, the same secondary text every panel uses.
  readonly property color secondaryText: "#bdae93"

  // Handed over by shell.qml. The layer surface's own `screen` is only resolved while mapped, so
  // geometry is computed from the screen object instead (same trap the toast module hit).
  property var targetScreen: null
  property string screenName: ""

  // Rows are icon + name only, so the panel is just as wide as the type needs.
  // Solid: the owner tested 80/90/95% alpha and judged the glass invisible over a dark desktop
  // (measured +1..+3 per channel), so there is no translucency left anywhere.
  readonly property int panelWidth: 520
  readonly property int rowHeight: 52
  readonly property int visibleRows: 9
  readonly property int listHeight: rowHeight * visibleRows

  property string query: ""
  property int selectedIndex: 0

  // Two modes share this panel: the application launcher, and an action menu handed over by a
  // script (`menu <name>`). The small menus (NAS, system) are rendered here now, so there is one
  // launcher UI on the machine instead of two.
  readonly property bool launcherOpen: root.screenName !== "" && PopupManager.isOpen(root.screenName, "launcher")
  readonly property bool menuOpen: root.screenName !== "" && PopupManager.isOpen(root.screenName, "menu")
  readonly property bool open: root.launcherOpen || root.menuOpen
  readonly property string menuName: root.menuOpen ? PopupManager.payload : ""
  readonly property string menuPath: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-menu-" + root.menuName

  // The surface is ALWAYS mapped and only drawn/focused while open. Mapping it on demand cost
  // ~70 ms on top of the ~85 ms the keybind already spends in process startup (measured), which is
  // exactly the lag a launcher cannot afford. An empty mask means the closed panel takes no input,
  // so pointer behaviour is identical to an unmapped surface.
  visible: true

  // Escape and typing must reach this surface; a grab-free surface would forward them to the app
  // underneath (see AGENTS.md, "Layer-shell surfaces are not windows").
  WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  exclusionMode: ExclusionMode.Ignore

  // Centred on the screen, unlike the bar popups: a launcher is not anchored to anything.
  anchors.top: true
  anchors.left: true
  margins.top: root.targetScreen
    ? Math.round((root.targetScreen.height - root.implicitHeight) / 2)
    : root.theme.popupTop
  margins.left: root.targetScreen
    ? Math.round((root.targetScreen.width - root.panelWidth) / 2)
    : root.theme.margins

  color: "transparent"

  implicitWidth: root.panelWidth
  implicitHeight: Math.ceil(col.implicitHeight) + 28

  onOpenChanged: {
    if (!root.open)
      return

    // Fresh search every time the launcher opens, and the field has to take focus explicitly:
    // the surface holding focus is not enough for typing.
    root.query = ""
    root.selectedIndex = 0
    input.text = ""
    input.forceActiveFocus()
    list.positionViewAtBeginning()

    if (root.menuName !== "")
      root.readMenu()

    PopupManager.claimSlot(root.panelWidth, root.implicitHeight, true, true)
  }

  // ---------------------------------------------------------------- hidden applications

  // Read once: the file only changes with a shell reload, and a launcher that reloads its own
  // hide list mid-session would be surprising.
  FileView {
    id: hidesFile

    path: Quickshell.shellRoot + "/launcher.hides"
    blockLoading: true
  }

  function normalizeId(id) {
    return String(id || "").replace(/\.desktop$/, "")
  }

  readonly property var hiddenIds: {
    const lines = hidesFile.text().split("\n")
    const map = ({})

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()

      if (line === "" || line.charAt(0) === "#")
        continue

      map[root.normalizeId(line)] = true
    }

    return map
  }

  // ---------------------------------------------------------------- action menus
  //
  // A script writes "<label>|<command>" lines to $XDG_RUNTIME_DIR/qs-menu-<name> and asks the shell
  // to open them. The lines become entries with the same shape as desktop entries, so searching,
  // keyboard handling and the look stay exactly the ones the launcher already has. Commands run
  // through `sh -c`, which is why a script can put a whole pipeline in that column.

  property string menuRaw: ""

  Process {
    id: menuReader

    command: ["true"]

    stdout: StdioCollector {
      onStreamFinished: root.menuRaw = String(text || "")
    }
  }

  // Read the file through an explicit command: a binding on `menuPath` was not evaluated yet when
  // this handler ran, and the first read hit "/qs-menu-" and came back empty.
  function readMenu() {
    if (root.menuName === "") {
      root.menuRaw = ""
      return
    }

    const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"

    menuReader.command = ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", runtime + "/qs-menu-" + root.menuName]

    if (menuReader.running)
      menuReader.running = false

    menuReader.running = true
  }

  onMenuNameChanged: root.readMenu()

  readonly property var menuItems: {
    const out = []
    const lines = root.menuRaw.split("\n")

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()

      if (line === "" || line.charAt(0) === "#")
        continue

      const bar = line.indexOf("|")

      if (bar <= 0)
        continue

      const label = line.slice(0, bar).trim()
      const command = line.slice(bar + 1).trim()

      if (label === "" || command === "")
        continue

      out.push({ name: label, id: label, genericName: "", icon: "", command: ["sh", "-c", command], runInTerminal: false })
    }

    return out
  }

  // ---------------------------------------------------------------- applications

  // A-Z by display name, hidden ones dropped. `noDisplay` is the standard "installed but not
  // meant to be launched" flag; the hides list covers the rest (it is the same list Nix turns
  // into tombstones for the other XDG consumers).
  readonly property var apps: {
    if (root.menuName !== "")
      return root.menuItems

    const source = DesktopEntries.applications.values || []
    const out = []

    for (let i = 0; i < source.length; i++) {
      const entry = source[i]

      if (!entry || !entry.name || entry.noDisplay)
        continue

      if (root.hiddenIds[root.normalizeId(entry.id)])
        continue

      out.push(entry)
    }

    out.sort(function (a, b) {
      const left = a.name.toLowerCase()
      const right = b.name.toLowerCase()

      if (left === right)
        return a.id < b.id ? -1 : 1

      return left < right ? -1 : 1
    })

    return out
  }

  // Substring beats subsequence, and an early hit beats a late one. Subsequence keeps short
  // queries usable ("gp" -> GIMP) without pulling in unrelated rows, because every character has
  // to appear in order.
  function score(name, query) {
    const haystack = String(name || "").toLowerCase()
    const needle = String(query || "").toLowerCase()

    if (needle === "")
      return 1

    const at = haystack.indexOf(needle)

    if (at === 0)
      return 1000
    if (at > 0)
      return 700 - Math.min(at, 200)

    let position = 0
    let total = 0
    let previous = -2

    for (let i = 0; i < haystack.length && position < needle.length; i++) {
      if (haystack.charAt(i) !== needle.charAt(position))
        continue

      // A hit on a word start ("F" in "File Manager") is worth more than one buried in the
      // middle, and consecutive characters keep short queries from matching noise.
      const wordStart = i === 0 || /[\s\-_.\/]/.test(haystack.charAt(i - 1))
      total += wordStart ? 60 : 10
      total += i === previous + 1 ? 25 : 0

      previous = i
      position += 1
    }

    return position === needle.length ? total : 0
  }

  readonly property var results: {
    const needle = root.query.trim()

    if (needle === "")
      return root.apps

    const hits = []

    for (let i = 0; i < root.apps.length; i++) {
      const entry = root.apps[i]
      const best = Math.max(
        root.score(entry.name, needle),
        root.score(entry.genericName, needle) - 20,
        root.score(entry.id, needle) - 60
      )

      if (best > 0)
        hits.push({ entry: entry, score: best })
    }

    hits.sort(function (a, b) {
      if (a.score !== b.score)
        return b.score - a.score

      return a.entry.name.toLowerCase() < b.entry.name.toLowerCase() ? -1 : 1
    })

    const out = []

    for (let i = 0; i < hits.length; i++)
      out.push(hits[i].entry)

    return out
  }

  // ---------------------------------------------------------------- launching

  function iconFor(entry) {
    const name = String(entry && entry.icon ? entry.icon : "")

    if (name.charAt(0) === "/")
      return "file://" + name

    const themed = name !== "" ? Quickshell.iconPath(name, true) : ""

    return themed !== "" ? themed : Quickshell.iconPath("application-x-executable", true)
  }

  // `command` is the parsed Exec line; the %f/%u field codes are removed because they are
  // placeholders for arguments we are not passing.
  function commandFor(entry) {
    let argv = (entry && entry.command ? entry.command : [])
      .map(String)
      .filter(function (word) { return !/^%[a-zA-Z]$/.test(word) })

    if (argv.length === 0)
      return []

    if (entry.runInTerminal)
      argv = ["ghostty", "-e"].concat(argv)

    return argv
  }

  function launch(entry) {
    if (!entry)
      return

    const argv = root.commandFor(entry)

    PopupManager.closeAll()

    if (argv.length > 0)
      Quickshell.execDetached(argv)
    else
      entry.execute()
  }

  function move(delta) {
    const count = root.results.length

    if (count === 0)
      return

    let next = root.selectedIndex + delta

    if (next < 0)
      next = count - 1
    if (next >= count)
      next = 0

    root.selectedIndex = next
    list.positionViewAtIndex(next, ListView.Contain)
  }

  // ---------------------------------------------------------------- surface

  // Empty region while closed: no input, nothing painted (opacity 0), but the layout still runs
  // so implicitHeight is correct for the very first open.
  mask: Region {
    item: root.open ? surface : null
  }

  Rectangle {
    id: surface

    anchors.fill: parent

    opacity: root.open ? 1 : 0
    // Same translucent surface as the bar (bgAlpha = 60% of the palette background), so the
    // wallpaper shows through the launcher instead of a flat opaque panel.
    color: root.theme.panelAlpha

    Behavior on opacity {
      NumberAnimation {
        duration: root.theme.duration(root.theme.motion)
        easing.type: Easing.OutCubic
      }
    }

    border.width: 2
    border.color: root.theme.accent
    radius: 0

    ColumnLayout {
      id: col

      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        spacing: 10

        Text {
          text: String.fromCodePoint(0xF002)

          color: root.theme.accent
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 6
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          TextInput {
            id: input

            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            clip: true

            color: root.theme.fg
            selectionColor: root.theme.accent
            selectedTextColor: root.theme.fg
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize + 6
            font.weight: Font.DemiBold

            // onTextEdited, not onTextChanged: the latter also fires for the programmatic reset
            // in onVisibleChanged and the query would never come back empty.
            onTextEdited: {
              root.query = text
              root.selectedIndex = 0
              list.positionViewAtBeginning()
            }

            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onReturnPressed: root.launch(root.results[root.selectedIndex])
            Keys.onEscapePressed: PopupManager.closeAll()
          }

          // Placeholder, because a bare TextInput has none.
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""

            text: root.menuName !== "" ? root.menuName.toUpperCase() + " menu" : "search applications…"

            color: root.secondaryText
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize + 6
          }
        }

        Text {
          text: root.results.length + (root.query.trim() === "" ? (root.menuName !== "" ? " actions" : " apps") : " match"
            + (root.results.length === 1 ? "" : "es"))

          color: root.secondaryText
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 2
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1

        color: root.theme.muted
        opacity: 0.5
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.listHeight

        ListView {
          id: list

          anchors.fill: parent

          model: root.results
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: list.width
            height: root.rowHeight

            // Selection is a colour change only: no border, no width change (AGENTS.md).
            color: index === root.selectedIndex ? root.theme.muted : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 10
              spacing: 10

              Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                Image {
                  id: appIcon

                  anchors.fill: parent

                  source: root.iconFor(modelData)
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 26
                  sourceSize.height: 26
                }

                // Fallback when the icon does not resolve (a missing theme icon is common).
                Text {
                  anchors.centerIn: parent
                  visible: appIcon.status !== Image.Ready

                  text: String.fromCodePoint(0xF17A)

                  color: root.secondaryText
                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 2
                }
              }

              // Long labels (audio profiles, app names) used to be cut with an ellipsis, so the end
              // was unreadable. Now the text stays put while it fits and slides only on the selected
              // row when it does not, with a pause at both ends so it can be read.
              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Text {
                  id: labelText

                  anchors.verticalCenter: parent.verticalCenter
                  x: 0

                  text: modelData.name

                  color: root.theme.fg
                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.fontSize + 4

                  readonly property bool overflows: implicitWidth > parent.width
                  readonly property int travel: Math.max(0, implicitWidth - parent.width + 20)

                  SequentialAnimation on x {
                    running: labelText.overflows && index === root.selectedIndex
                    loops: Animation.Infinite

                    // ~75 px/s with short holds: fast enough to read without waiting, slow enough
                    // that the eye can follow. The old 45 ms/px was ~22 px/s.
                    PauseAnimation { duration: 450 }
                    NumberAnimation {
                      to: -labelText.travel
                      duration: Math.max(700, labelText.travel * 13)
                      easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 450 }
                    NumberAnimation { to: 0; duration: 260; easing.type: Easing.InOutQuad }

                    onStopped: labelText.x = 0
                  }
                }
              }
            }

            HoverHandler {
              onHoveredChanged: {
                if (hovered)
                  root.selectedIndex = index
              }
            }

            TapHandler {
              acceptedButtons: Qt.LeftButton

              onTapped: root.launch(modelData)
            }
          }
        }

        // Nothing matched: say so instead of leaving an empty box.
        Text {
          anchors.centerIn: parent
          visible: root.results.length === 0

          text: "no matches"

          color: root.secondaryText
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 2
        }
      }
    }
  }

  PopupKeys {
    active: root.visible
  }
}
