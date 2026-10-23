pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Which output currently has keyboard focus, as far as niri is concerned.
//
// A niri keybind fires without a pointer event, so a popup opened from a shortcut has to pick an
// output explicitly - otherwise it would land on whatever screen the shell guesses, which is
// exactly the multi-monitor bug the click path already avoids.
//
// The answer comes over niri's IPC socket, which stays connected for the whole session: the request
// is one write and the reply lands in the next event loop turn (~1 ms). Spawning
// `niri msg focused-output` cost ~22 ms and survives only as a fallback for a socket that is not
// connected (niri restarting, no NIRI_SOCKET in the environment).
Singleton {
  id: root

  // The one callback waiting for an answer. A second press while a request is still in flight
  // simply replaces it, which collapses a double press into one toggle.
  property var pending: null

  function withFocusedOutput(callback) {
    root.pending = callback

    if (niri.connected) {
      niri.write("\"FocusedOutput\"\n")
      guard.restart()
      return
    }

    probeTimer.restart()
  }

  function handleReply(line) {
    if (root.pending === null)
      return

    let reply = null

    try {
      reply = JSON.parse(line)
    } catch (error) {
      return
    }

    // Event lines also arrive on this socket; only an Ok reply to FocusedOutput matters.
    if (!reply || !reply.Ok || !("FocusedOutput" in reply.Ok))
      return

    const output = reply.Ok.FocusedOutput
    root.resolve(output && output.name ? output.name : "")
  }

  function resolve(text) {
    const match = /\(([^)]+)\)/.exec(String(text))
    let name = match ? match[1] : String(text || "")

    if (name === "" && Quickshell.screens.length > 0)
      name = Quickshell.screens[0].name

    const callback = root.pending
    root.pending = null

    if (callback)
      callback(name)
  }

  Socket {
    id: niri

    path: Quickshell.env("NIRI_SOCKET") || ""
    connected: true

    parser: SplitParser {
      onRead: function (line) {
        root.handleReply(line)
      }
    }
  }

  // If the socket stays quiet (it drops when niri reloads), fall back to the CLI so a keybind still
  // opens something instead of nothing.
  Timer {
    id: guard

    interval: 150
    repeat: false

    onTriggered: {
      if (root.pending !== null)
        probeTimer.restart()
    }
  }

  Timer {
    id: probeTimer

    interval: 0
    repeat: false

    onTriggered: probe.running = true
  }

  Process {
    id: probe

    command: ["niri", "msg", "focused-output"]

    stdout: StdioCollector {
      onStreamFinished: root.resolve(this.text)
    }

    onExited: function (exitCode) {
      // A missing reply still has to release the callback: resolve() runs from the stdout
      // collector, and an empty stream resolves to the fallback screen.
      if (exitCode !== 0 && root.pending !== null)
        root.resolve("")
    }
  }
}
