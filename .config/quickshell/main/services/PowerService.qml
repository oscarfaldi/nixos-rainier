pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Idle power policy, at SHELL level: exactly THREE controls and one idle daemon.
//
//   1. display timeout   -> `niri msg action power-off-monitors` (screen off; the system and
//      every background job - encoding, rendering, downloads - keep running, and `resume`
//      turns the screen back on).
//   2. automatic suspend -> `systemctl suspend`, IDLE-triggered only. Suspend, never
//      shutdown, and there is no other suspend trigger anywhere in this shell.
//   3. session lock      -> the Quickshell lock screen, IDLE-triggered only. Independent of
//      the other two: "never" here still locks before every suspend.
//
// swayidle is the only idle mechanism: this service generates its argument list from the
// two values below and restarts it whenever one of them changes. Nothing else may spawn a
// second daemon or a competing handler.
//
// `-C /dev/null` is passed on purpose. swayidle ADDS the events of its config file to the
// command-line events ("specifying events in the config and as arguments is not mutually
// exclusive"), so a deployed ~/.config/swayidle/config would silently impose its own
// timeouts ON TOP of whatever is selected here - measured: without this flag swayidle
// registers the config file's 1h/2h/4h events in addition to the generated ones.
//
// The lock timeout used to be a fixed 2h the panel could not show, so the lock screen
// appeared with no visible cause mid-work. It is a control now (LOCK AFTER IDLE, 0 =
// never). The `before-sleep` lock is NOT conditional - resuming from a suspend with the
// session unlocked is never wanted, and that path only runs when the machine actually
// suspends.
Singleton {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
  readonly property string stateFile: root.stateDir + "/power.json"

  // -------------------------------------------------------------------- policy
  // Minutes; 0 means "never". Every default is NEVER on purpose: an idle action the owner
  // did not pick must never arm itself on a fresh install (reinstall = no re-clicking).
  property int displayMinutes: 0
  property int autoSuspendMinutes: 0

  // Every entry is an absolute swayidle timeout; the daemon sorts them by seconds. The two
  // lists are independent, so a lock chosen earlier than the screen-off timeout covers a
  // display that is still lit - allowed on purpose, it is the owner's call.
  readonly property var displayOptions: [
    { "key": 10, "label": "10M" },
    { "key": 30, "label": "30M" },
    { "key": 60, "label": "1H" },
    { "key": 0, "label": "NEVER" }
  ]

  readonly property var autoSuspendOptions: [
    { "key": 60, "label": "1H" },
    { "key": 180, "label": "3H" },
    { "key": 360, "label": "6H" },
    { "key": 0, "label": "NEVER" }
  ]

  // Minutes; 0 means "never". The before-sleep lock ignores this value.
  property int lockMinutes: 0

  readonly property var lockOptions: [
    { "key": 30, "label": "30M" },
    { "key": 60, "label": "1H" },
    { "key": 120, "label": "2H" },
    { "key": 0, "label": "NEVER" }
  ]

  // --------------------------------------------------------- the idle daemon
  // Set to false by a test copy of the shell so a second instance never fights the live
  // swayidle for ownership.
  readonly property bool manageIdle: true

  // The daemon's arguments, generated from the two controls. Timeouts are handed over in
  // ascending order and the display-off pair keeps its `resume` command adjacent, which is
  // what turns the screen back on at the next activity.
  readonly property string idleArgs: {
    const list = []

    if (root.displayMinutes > 0)
      list.push({ "sec": root.displayMinutes * 60, "kind": "display" })

    if (root.lockMinutes > 0)
      list.push({ "sec": root.lockMinutes * 60, "kind": "lock" })

    if (root.autoSuspendMinutes > 0)
      list.push({ "sec": root.autoSuspendMinutes * 60, "kind": "suspend" })

    list.sort(function (a, b) { return a.sec - b.sec })

    const parts = []

    for (let i = 0; i < list.length; ++i) {
      const item = list[i]

      if (item.kind === "display")
        parts.push("timeout " + item.sec
          + " 'niri msg action power-off-monitors'"
          + " resume 'niri msg action power-on-monitors'")
      else if (item.kind === "lock")
        parts.push("timeout " + item.sec + " '" + lockCmd + "'")
      else
        parts.push("timeout " + item.sec + " 'systemctl suspend'")
    }

    parts.push("before-sleep '" + lockCmd + "'")

    return parts.join(" ")
  }

  // `pkill -x swayidle` first: it retires any daemon started from the old config file, so
  // this shell is the only owner. pkill exiting 1 (nothing matched) is fine - the command
  // sequence continues either way.
  readonly property string idleCommand:
    "swayidle_bin=$(command -v swayidle || echo /run/current-system/sw/bin/swayidle); "
    + "pkill -x swayidle 2>/dev/null; sleep 0.2; exec \"$swayidle_bin\" -C /dev/null "
    + root.idleArgs

  readonly property string idleSignature:
    root.displayMinutes + "|" + root.autoSuspendMinutes + "|" + root.lockMinutes

  property bool idleLoaded: false
  property bool idleRestartPending: false

  onIdleSignatureChanged: {
    if (root.idleLoaded && root.manageIdle)
      root.restartIdle()
  }

  // Idle timeout and before-sleep both go through the Quickshell lock screen now.

  readonly property string lockCmd: Quickshell.env("HOME") + "/System/.config/quickshell/scripts/qs-lock"


  function startIdle() {
    if (!root.manageIdle) {
      console.log("POWER idle management disabled in this instance")
      return
    }

    root.idleRestartPending = false
    idleProcess.command = ["bash", "-c", root.idleCommand]
    idleProcess.running = true
    console.log("POWER swayidle started: " + root.idleArgs)
  }

  // A Process must not be stopped and started in the same tick (the new command is
  // dropped), so the restart happens on the next tick.
  function restartIdle() {
    idleProcess.running = false
    root.idleRestartPending = true
    idleRestartTimer.restart()
    console.log("POWER idle policy changed -> restarting swayidle: " + root.idleArgs)
  }

  function applyIdle() {
    root.idleLoaded = true

    if (!root.manageIdle)
      return

    if (idleProcess.running)
      root.restartIdle()
    else
      root.startIdle()
  }

  Timer {
    id: idleRestartTimer

    interval: 0
    repeat: false

    onTriggered: root.startIdle()
  }

  // Safety net: if the state file is missing or neither load callback ever fires, the idle
  // daemon still has to come up - an idle policy that silently does not exist is the one
  // failure that would go unnoticed until the machine never suspends.
  Timer {
    interval: 2000
    repeat: false
    running: true

    onTriggered: {
      if (!root.idleLoaded) {
        console.warn("POWER state file load never reported back, applying the policy anyway")
        root.applyIdle()
      }
    }
  }

  Process {
    id: idleProcess

    command: []
    running: false

    onExited: function (exitCode) {
      if (root.idleRestartPending)
        return

      if (exitCode === 0)
        console.log("POWER swayidle exited with 0")
      else
        console.warn("POWER swayidle exited with " + exitCode)
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text !== "")
          console.warn("POWER swayidle stderr: " + text)
      }
    }
  }

  // The shell outlives the daemon: if swayidle is gone (crash, a stray kill) the idle
  // policy would silently stop existing, so put it back.
  Timer {
    interval: 60000
    repeat: true
    running: root.manageIdle && root.idleLoaded

    onTriggered: {
      if (!idleProcess.running && !root.idleRestartPending) {
        console.warn("POWER swayidle was not running, restarting it")
        root.startIdle()
      }
    }
  }

  // ------------------------------------------------------------- persistence
  function setDisplay(minutes) {
    root.displayMinutes = minutes
    root.persist()
  }

  function setAutoSuspend(minutes) {
    root.autoSuspendMinutes = minutes
    root.persist()
  }

  function setLock(minutes) {
    root.lockMinutes = minutes
    root.persist()
  }

  function persist() {
    stateWriter.write(JSON.stringify({
      "displayMinutes": root.displayMinutes,
      "autoSuspendMinutes": root.autoSuspendMinutes,
      "lockMinutes": root.lockMinutes
    }))
  }

  // A stored value that is not one of the offered options (an older file, a hand edit)
  // falls back to the default instead of driving the daemon with something the UI cannot
  // show - the UI must never display a selection that differs from the real config.
  function allowedValue(value, options, fallback) {
    for (let i = 0; i < options.length; ++i) {
      if (options[i].key === value)
        return value
    }

    return fallback
  }

  Process {
    id: stateWriter

    function write(value) {
      running = false
      command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$2\" > \"$3\"",
                 "sh", root.stateDir, value, root.stateFile]
      running = true
    }
  }

  FileView {
    id: powerFile

    path: root.stateFile
    blockLoading: true
    watchChanges: false
    printErrors: false

    onLoaded: {
      const text = powerFile.text().trim()

      if (text === "") {
        root.applyIdle()
        return
      }

      let stored = null
      try {
        stored = JSON.parse(text)
      } catch (error) {
        stored = null
      }

      if (stored) {
        root.displayMinutes = root.allowedValue(Number(stored.displayMinutes),
                                               root.displayOptions, root.displayMinutes)
        root.autoSuspendMinutes = root.allowedValue(Number(stored.autoSuspendMinutes),
                                                   root.autoSuspendOptions,
                                                   root.autoSuspendMinutes)
        root.lockMinutes = root.allowedValue(Number(stored.lockMinutes),
                                             root.lockOptions, root.lockMinutes)
      }

      console.log("POWER policy restored: display=" + root.displayMinutes
                  + "m suspend=" + root.autoSuspendMinutes + "m lock=" + root.lockMinutes + "m")
      root.applyIdle()
    }

    onLoadFailed: (error) => {
      root.applyIdle()
    }
  }
}
