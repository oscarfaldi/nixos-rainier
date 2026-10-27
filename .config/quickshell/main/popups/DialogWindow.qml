import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"

// Report dialog as a REAL toplevel window (FloatingWindow), not a layer surface.
//
// The compositor manages it like any other window: tile it, lock it, resize it, maximise it, close
// it with the compositor's close-window key - while the rest of the desktop stays fully usable. It
// is what the two report scripts show their text in.
//
// LIFECYCLE, and why this file has no `visible = true` toggle: a toplevel that has been closed is
// dead. `visible` can be written but nothing comes back (Quickshell emits `closed`, the backing
// window is gone, and the next show is silently ignored - no error at all). So a dialog instance
// lives exactly one open: shell.qml creates it per request and destroys it on `closedByUser`.
// Windows are also created with `visible: true` for the same reason - one transition only.
//
// The script writes a text report to a file and asks the shell to show it; the first line of the
// file is `TITLE: <window title>` and is stripped from the body.
FloatingWindow {
  id: root

  readonly property Theme theme: Theme { }

  // Gruvbox light4, the same secondary text every panel uses.
  readonly property color secondaryText: "#bdae93"
  readonly property color passColor: root.theme.success
  readonly property color failColor: root.theme.warning

  // Set by shell.qml right after creation.
  property string reportPath: ""
  property string reportTitle: ""

  property string body: ""

  title: root.reportTitle !== "" ? root.reportTitle : "Report"
  color: root.theme.panel
  visible: true

  // The niri rule for app-id org.quickshell sizes it 900x700 floating; these are the same numbers
  // so the window is right even before the rule applies.
  width: 900
  height: 700

  // A toplevel belongs to ONE output and can only map once it has one. If the shell starts before
  // the compositor publishes outputs, a window created with no screen never appears at all.
  screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

  Component.onCompleted: {
    // Open on the output the owner is looking at. ScreenFocus answers over niri's socket (~1 ms).
    ScreenFocus.withFocusedOutput(function (name) {
      for (let i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === name) {
          root.screen = Quickshell.screens[i]
          break
        }
      }

      if (!root.screen && Quickshell.screens.length > 0)
        root.screen = Quickshell.screens[0]

      if (root.reportPath !== "")
        reader.running = true
    })
  }

  // Actually hides the window. It used to only emit a signal, and the receiver that destroyed the
  // window was removed with the lifecycle rewrite, so CLOSE and Escape did nothing at all.
  // Hiding is safe: a hidden window is destroyed and replaced on the next request.
  function closeReport() {
    root.visible = false
  }

  Process {
    id: reader

    command: ["cat", root.reportPath]

    stdout: StdioCollector {
      onStreamFinished: root.loadReport(this.text)
    }
  }

  function loadReport(text) {
    const all = String(text || "")
    const cut = all.indexOf("\n")
    const first = cut >= 0 ? all.slice(0, cut) : all

    if (first.indexOf("TITLE: ") === 0) {
      root.reportTitle = first.slice(7)
      root.body = cut >= 0 ? all.slice(cut + 1) : ""
    } else {
      root.body = all
    }

    // A report starts on its first row: leading empty lines only push the heading down (the old
    // text-info dialogs did the same). Trailing blanks are kept as they are, they are part of the layout.
    root.body = root.body.replace(/^\s*\n/, "")
  }

  // ---------------------------------------------------------------- colouring
  //
  // The scripts stay pure text: they were not rewritten to emit JSON just so two words could be
  // coloured. The rules below are the shapes those reports already have.
  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  function isRule(line) {
    return /^[\u2500\u2501\u2504-\u2508\u2550-]{3,}\s*$/.test(String(line))
  }

  readonly property string html: {
    const rows = String(root.body || "").split("\n")
    const out = []

    for (let i = 0; i < rows.length; i++) {
      const line = rows[i]
      const next = i + 1 < rows.length ? rows[i + 1] : ""
      const safe = root.escapeHtml(line)

      // An empty source line is just an empty row: the rows are joined with a newline, so pushing
      // a <br> here added a second break and Qt rendered the gap as a paragraph (~68 px instead of
      // the ~18 px line pitch). Keep it empty and let the join do the work.
      if (line.trim() === "") {
        out.push("")
        continue
      }

      // A line that is followed by a rule is a section header.
      if (root.isRule(next)) {
        out.push('<span style="color:' + root.theme.accent + ';font-weight:bold">' + safe + "</span>")
        continue
      }

      if (/\b(FAILED|FAILING_NOW|FAILING|BAD|CRITICAL)\b/.test(line)) {
        out.push('<span style="color:' + root.failColor + '">' + safe + "</span>")
        continue
      }

      if (/\b(PASSED|OK|GOOD|HEALTHY)\b/.test(line)) {
        out.push('<span style="color:' + root.passColor + '">' + safe + "</span>")
        continue
      }

      // "Label: value" - dim the label, keep the value at full contrast.
      const colon = line.indexOf(":")
      if (colon > 0 && colon < 30 && /^\s*[A-Za-z][\w .'\-\/()]*$/.test(line.slice(0, colon))) {
        const label = root.escapeHtml(line.slice(0, colon + 1))
        out.push('<span style="color:' + root.secondaryText + '">' + label + "</span>"
          + safe.slice(label.length))
        continue
      }

      out.push(safe)
    }

    // ONE block with white-space:pre, not a <pre>: inside <pre> Qt turns every newline into its
    // own paragraph, and an empty line then costs about three line heights (measured 59 px
    // against an 18 px pitch). A single block keeps the pitch uniform, blanks included.
    // Rows are joined with <br/>, not with newlines: a "\n" inside rich text starts a NEW block
    // and Qt gives blocks their own spacing, so an empty line cost ~40 px instead of the 19 px
    // line pitch. <br/> keeps one block and one uniform pitch, blanks included; white-space:pre
    // keeps the column alignment the scripts produce with padded labels.
    return '<div style="margin:0;white-space:pre">' + out.join("<br/>") + "</div>"
  }

  // ---------------------------------------------------------------- surface

  Rectangle {
    anchors.fill: parent

    color: root.theme.panel
    border.width: 2
    border.color: root.theme.accent
    radius: 0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 10

        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight

          text: root.reportTitle

          color: root.theme.fg
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize + 2
          font.weight: Font.Bold
        }

        // COPY: the report is a file on disk, so the clipboard gets the text without the TITLE line.
        Rectangle {
          Layout.preferredWidth: 74
          Layout.preferredHeight: 28

          color: copyHover.hovered ? root.theme.accent : "transparent"

          border.width: 1
          border.color: root.secondaryText

          Text {
            anchors.centerIn: parent

            text: "COPY"

            color: root.theme.fg
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 1
            font.weight: Font.DemiBold
          }

          HoverHandler {
            id: copyHover

            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            acceptedButtons: Qt.LeftButton

            onTapped: copier.running = true
          }
        }

        Rectangle {
          Layout.preferredWidth: 74
          Layout.preferredHeight: 28

          color: closeHover.hovered ? root.theme.accent : "transparent"

          border.width: 1
          border.color: root.secondaryText

          Text {
            anchors.centerIn: parent

            text: "CLOSE"

            color: root.theme.fg
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.fontSize - 1
            font.weight: Font.DemiBold
          }

          HoverHandler {
            id: closeHover

            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            acceptedButtons: Qt.LeftButton

            onTapped: root.closeReport()
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1

        color: root.secondaryText
        opacity: 0.4
      }

      Flickable {
        id: flick

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: editor.width
        contentHeight: editor.height

        TextEdit {
          id: editor

          textFormat: TextEdit.RichText
          text: root.html

          readOnly: true
          selectByMouse: true
          wrapMode: TextEdit.NoWrap
          cursorVisible: false

          color: root.theme.fg
          selectionColor: root.theme.accent
          selectedTextColor: root.theme.fg
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.fontSize

          width: Math.max(flick.width - 14, Math.ceil(contentWidth) + 4)
          height: Math.max(flick.height - 4, Math.ceil(contentHeight) + 4)
        }

        // Scrollbars: drawn by hand because the shell does not import QtQuick Controls.
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 2
          y: flick.visibleArea.yPosition * flick.height
          width: 4
          height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
          visible: flick.visibleArea.heightRatio < 1

          color: root.theme.muted
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 2
          x: flick.visibleArea.xPosition * flick.width
          height: 4
          width: Math.max(24, flick.visibleArea.widthRatio * flick.width)
          visible: flick.visibleArea.widthRatio < 1

          color: root.theme.muted
        }
      }
    }
  }

  // Clipboard: `wl-copy` reads the file, minus the TITLE line.
  Process {
    id: copier

    command: ["sh", "-c", "tail -n +2 \"$1\" | wl-copy", "sh", root.reportPath]
  }

  // Escape closes it like any dialog.
  Shortcut {
    sequence: "Escape"
    enabled: root.visible
    onActivated: root.closeReport()
  }
}
