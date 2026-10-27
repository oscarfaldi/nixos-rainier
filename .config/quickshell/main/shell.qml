import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services
import "bar"
import "popups"
import "theme"
import "wallpaper"

// Shell root.
//
// A Scope (not a window) wraps everything for one reason: the IpcHandler below must exist
// exactly ONCE. Declared inside the per-screen Variants it would be created once per output and
// the target would be ambiguous.
//
// Keyboard shortcuts: niri keybinds cannot call into a running Quickshell directly, so the binds
// spawn `.config/niri/qs-popup` which resolves this instance and calls one of the functions
// below. Each one asks niri which output has focus (ScreenFocus) and toggles that screen's
// popup, so a shortcut behaves like clicking the matching bar module.
Scope {
  id: shellRoot

  // Keybind command channel.
  //
  // niri can only spawn a process, and `qs ipc` costs ~40 ms (a Qt binary starting up) - the last
  // real slice of a popup's latency. Instead the helper writes one line into this FIFO, which the
  // shell reads like input: a few ms end to end and no client binary at all.
  // Path carries the pid on purpose. With one shared path, a reader left over from a previous
  // shell instance keeps the FIFO open, the kernel hands each line to whichever reader wakes first,
  // and commands arrive cut in half ("0-ptrbt" instead of the command). A per-instance path makes a
  // stale reader harmless; it can only read the old pipe.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

  readonly property string commandPipe: runtimeDir + "/quickshell-cmd-" + Quickshell.processId

  Process {
    id: pipeSetup

    running: true
    // Create this instance's pipe, then clean up pipes whose owner process is gone.
    //
    // The cleanup is deliberately narrow: only THIS runtime dir, only pipes of dead pids, and only
    // the readers belonging to those dead pipes. A global `pkill -f` pattern here killed the LIVE
    // shell's reader whenever any second instance started - a diagnostic run with its own
    // XDG_RUNTIME_DIR was enough - and every keybind went silent while the bar still looked healthy.
    command: [
      "sh", "-c",
      "for f in \"$1\"/quickshell-cmd-*; do " +
      "[ -p \"$f\" ] || continue; " +
      "owner=${f##*-}; " +
      "[ -d \"/proc/$owner\" ] && continue; " +
      "for p in $(pgrep -f \"quickshell-cmd-$owner\" 2>/dev/null); do " +
      "[ \"$p\" = \"$$\" ] && continue; kill \"$p\" 2>/dev/null || true; done; " +
      "rm -f \"$f\"; done; " +
      "[ -p \"$1/quickshell-cmd-$2\" ] || mkfifo \"$1/quickshell-cmd-$2\"",
      "sh", runtimeDir, String(Quickshell.processId)
    ]

    // The reader must not start before the FIFO exists.
    onExited: pipeReader.running = true
  }

  Process {
    id: pipeReader

    // `read` returns on EOF, so the outer loop reopens the FIFO after every writer closes and the
    // line is re-emitted on stdout, where SplitParser turns it back into one command.
    running: false
    command: [
      "sh", "-c",
      "while :; do while IFS= read -r line; do echo \"$line\"; done < \"$1\"; done",
      "sh", shellRoot.commandPipe
    ]

    stdout: SplitParser {
      onRead: function (line) {
        shellRoot.runCommand(line)
      }
    }

    // This loop is the only path from a keybind to the shell. If it dies, Mod+D and every other
    // shortcut stop working with no visible symptom (qs-popup still exits 0), so restart it.
    onExited: pipeRestart.restart()
  }

  Timer {
    id: pipeRestart
    interval: 300
    onTriggered: pipeReader.running = true
  }

  // Timestamp written on every `ping`, read back by qs-check. Cheap enough to run any time.
  Process {
    id: pingAck
    running: false
    command: ["sh", "-c", "date +%s > \"$1/qs-shell-ping\"", "sh", shellRoot.runtimeDir]
  }

  // Report dialogs. Real toplevel windows (not layer surfaces), one per report kind so an inspect
  // report and a SMART report can be open at the same time.
  //
  // They are CREATED PER REQUEST and destroyed when they close. A toplevel that has been closed is
  // dead: Quickshell emits `closed`, the backing window is gone, and setting `visible = true` again
  // is silently ignored - which looked exactly like "inspect does nothing" until the shell was
  // restarted. Creating a fresh window per open is the only reliable lifecycle.
  Component {
    id: reportDialogComponent

    DialogWindow { }
  }

  property var reportWindows: ({})

  // Live progress window for the conversion scripts. One at a time: a new job replaces whatever is
  // on screen, created per request for the same lifecycle reason as the report dialogs below.
  Component {
    id: jobWindowComponent

    JobWindow { }
  }

  property var jobWindow: null

  function showJob(path, title) {
    if (shellRoot.jobWindow !== null) {
      const previous = shellRoot.jobWindow
      shellRoot.jobWindow = null
      previous.visible = false
      previous.destroy()
    }

    const created = jobWindowComponent.createObject(null, { "statusPath": path, "initialTitle": title })

    if (created === null) {
      return
    }

    created.statusPath = path
    shellRoot.jobWindow = created
  }

  function showReport(kind, path) {
    const previous = shellRoot.reportWindows[kind]

    if (previous !== undefined && previous !== null) {
      delete shellRoot.reportWindows[kind]
      shellRoot.reportWindows = Object.assign({}, shellRoot.reportWindows)
      previous.destroy()
    }

    const created = reportDialogComponent.createObject(null, { "reportPath": path })

    if (created === null)
      return

    shellRoot.reportWindows[kind] = created
    shellRoot.reportWindows = Object.assign({}, shellRoot.reportWindows)
  }

  function runCommand(line): void {
    const verb = String(line || "").trim()

    if (verb === "")
      return

    // `theme` - the palette on disk changed; re-read it instead of restarting the shell.
    if (verb === "theme") {
      ThemeState.reload()

      return
    }

    // `ping` - a reachability probe for `qs-check`. It proves a command travelled all the way from
    // the keybind helper through the FIFO into the QML; "the shell process exists" proves nothing
    // about delivery, which is exactly how a dead reader stayed invisible.
    if (verb === "ping") {
      pingAck.running = false
      pingAck.running = true

      return
    }

    // `menu <name>` - an action menu rendered by the launcher (the scripts hand it over this way).
    if (verb.indexOf("menu ") === 0) {
      const menu = verb.slice(5).trim()

      if (menu !== "")
        ScreenFocus.withFocusedOutput(function (name) { PopupManager.toggle(name, "menu", menu) })

      return
    }

    // `job <statuspath>|<title>` - progress window for a script started by qs-job. The title rides
    // along because the window has to be titled before it maps (niri matches its size rule on it).
    if (verb.indexOf("job ") === 0) {
      const rest = verb.slice(4)
      const bar = rest.indexOf("|")
      const status = (bar >= 0 ? rest.slice(0, bar) : rest).trim()
      const title = bar >= 0 ? rest.slice(bar + 1).trim() : ""

      if (status !== "")
        shellRoot.showJob(status, title)

      return
    }

    // `dialog <kind> <path>` - no output routing: the compositor places these windows.
    if (verb.indexOf("dialog ") === 0) {
      const kind = verb.split(" ")[1] || ""
      const path = verb.slice(("dialog " + kind + " ").length)

      if ((kind === "inspect" || kind === "smart") && path !== "")
        shellRoot.showReport(kind, path)

      return
    }

    ScreenFocus.withFocusedOutput(function (name) {
      if (verb === "close") {
        PopupManager.closeAll()
        return
      }

      PopupManager.toggle(name, verb)
    })
  }

  // The keybind helper addresses this instance with `qs ipc --pid <pid>`, and resolving that with
  // `pgrep -f` costs ~50 ms - the single biggest slice of the launcher's latency. Writing the pid
  // once at startup lets the helper read it with a shell builtin instead.
  Process {
    running: true
    command: [
      "sh", "-c",
      // Trailing newline matters: `read` returns non-zero at EOF without one, and every consumer
      // would treat the pid as empty.
      "printf '%s\\n' \"$1\" > \"${XDG_RUNTIME_DIR:-/tmp}/quickshell-shell.pid\"",
      "sh", String(Quickshell.processId)
    ]
  }

  IpcHandler {
    target: "shell"

    // Power menu: suspend / restart / shutdown / lock / logout.
    function power(): void {
      ScreenFocus.withFocusedOutput(function (name) {
        PopupManager.toggle(name, "system")
      })
    }

    // Audio: output volume, input volume, per-stream levels.
    function audio(): void {
      ScreenFocus.withFocusedOutput(function (name) {
        PopupManager.toggle(name, "audio")
      })
    }

    // Power management policy (screen off after / sleep after idle).
    function powermanagement(): void {
      ScreenFocus.withFocusedOutput(function (name) {
        PopupManager.toggle(name, "power")
      })
    }

    // Network panel (also reachable from the bar's network module).
    function network(): void {
      ScreenFocus.withFocusedOutput(function (name) {
        PopupManager.toggle(name, "network")
      })
    }

    // Application launcher: searchable, A-Z, keyboard-first.
    function launcher(): void {
      ScreenFocus.withFocusedOutput(function (name) {
        PopupManager.toggle(name, "launcher")
      })
    }

    // Closes whatever popup is open, on any screen.
    function close(): void {
      PopupManager.closeAll()
    }

    // Same commands as the FIFO, reachable over `qs ipc` (fallback path / scripts).
    function run(command: string): void {
      shellRoot.runCommand(command)
    }

    // Dismisses every notification toast, on every screen. This is NOT a notification centre -
    // the toasts are the whole UI - it is just the "clear them" action a hotkey can call, and
    // what the test scripts use to start from an empty screen.
    function notifications(): void {
      Notifications.dismissAll()
    }
  }

  // Desktop wallpaper: one background-layer surface per output, drawn from the state file
  // theme-apply owns. Declared before the bar and the popups so the layer exists before anything
  // above it, and it holds no state of its own to get out of sync.
  Wallpaper {}

  Variants {
    model: Quickshell.screens

    delegate: Component {
      Item {
        required property var modelData

        // Click shield: mapped ONLY while some popup is open (any screen).
        // Its input mask is the full screen minus the bar strip and the
        // popup panel slot, so clicks on the bar and on the popup panel pass
        // through to them, and ANY other click (desktop, app windows,
        // wallpaper) closes the popup. When no popup is open the shield is
        // not mapped at all and pointer behavior is 100% stock niri.
        PanelWindow {
          id: shield

          readonly property bool active: PopupManager.activeName !== ""

          // ALWAYS mapped, with an empty input mask while nothing is open. Mapping this surface
          // at open time cost ~180 ms (measured, identical for every panel), so it is paid once at
          // startup instead. An empty mask means zero input footprint: the pointer sees niri.
          visible: true

          screen: modelData

          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Top

          anchors {
            top: true
            bottom: true
            left: true
            right: true
          }

          color: "transparent"

          MouseArea {
            anchors.fill: parent
            enabled: shield.active

            onClicked: PopupManager.closeAll()
          }

          // Empty while no popup is open (0x0 region = no input), the subtract mask while one is.
          mask: shield.active ? activeMask : idleMask

          Region {
            id: idleMask
          }

          Region {
            id: activeMask

            intersection: Intersection.Subtract

            regions: [
              Region { item: barStrip },
              Region { item: panelSlot }
            ]
          }

          // mask geometry references (anchor-driven, per-screen resolution)
          Item {
            id: barStrip

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            // bar strip: margin(13) + height(35) + 2px tolerance. Keep it
            // tight: every pixel below the bar belongs to the click-to-close
            // region, not to the bar pass-through region.
            height: 50
          }

          Item {
            id: panelSlot

            anchors.top: parent.top
            anchors.right: parent.right
            // Follows the panel that is actually open: each panel claims its
            // own size on show (PopupManager.claimSlot), so this region is
            // never larger than the panel and no dead strip is left beside it.
            // topMargin must equal theme.popupTop; the 2px covers the border.
            anchors.topMargin: PopupManager.slotVerticalCenter
              ? Math.round((parent.height - PopupManager.slotHeight) / 2) - 1
              : 60
            // Right-aligned panels sit flush with the bar's right edge; centered
            // panels keep their region under the middle of the bar, matching where
            // the panel actually is.
            anchors.rightMargin: PopupManager.slotCentered
              ? Math.round((parent.width - PopupManager.slotWidth) / 2) - 1
              : 9
            width: PopupManager.slotWidth + 2
            height: PopupManager.slotHeight + 2
          }
        }

        Bar {
          screen: modelData
        }

        // Notification toasts: top-centre of the output that owns the current stack.
        NotificationToast {
          screen: modelData
          screenName: modelData.name
          targetScreen: modelData
        }

        // Application launcher, one per output, opened from Mod+D through qs-popup.
        Launcher {
          screen: modelData
          screenName: modelData.name
          targetScreen: modelData
        }
      }
    }
  }
}
