pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Countdown and one-shot alarm, at SHELL level.
//
// Why here and not in the popup: the countdown must keep running while the panel is
// closed and while the owner switches between the three bar panels, and it must not
// lose time when a UI update callback arrives late. The truth is always an absolute
// deadline (`cdEndAt`, `alarmTargetAt`), the readout is computed from it, and the
// popup is only a view. A 250 ms heartbeat refreshes `nowMs` for the readout and
// checks the deadlines; the finish/ring event fires exactly once because the state
// flips before anything is sent.
//
// Notification and sound go through their own adapters (Notifier, SoundFx) so the
// backend stays in the shell, so sound and notification never drift apart - without
// touching this logic.
//
// Durations are HH:MM:SS everywhere in the interface: one typed input, validated, and
// the same format for the remaining time. A shared reminder text rides along with the
// active timer or alarm and ends up in the notification body.
//
// Persistence: one JSON line in ~/.local/state/quickshell/timer.json. A reload (or a
// shell restart) restores the state; because the deadlines are absolute, a running
// countdown continues with the right remaining time. LIMIT: while the Quickshell
// process is not running nothing can fire - an alarm that was due while the shell was
// down is shown as RINGING and reported once when the shell starts again.
Singleton {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
  readonly property string stateFile: root.stateDir + "/timer.json"

  // The largest duration the input accepts, so a typo cannot schedule a week.
  readonly property int maxHours: 23

  // -------------------------------------------------------------------- modes
  property string mode: "countdown"          // countdown | alarm

  // --------------------------------------------------------------- countdown
  property string cdInput: "00:00:00"        // the typed duration, HH:MM:SS
  property double durationMs: 0              // parsed from cdInput when it is valid
  property string cdStatus: "idle"           // idle | running | paused | finished
  property double cdEndAt: 0                 // absolute deadline while running
  property double cdFrozenMs: 0              // remaining while idle/paused/finished

  // ------------------------------------------------------------------- alarm
  property string alarmTime: "07:30"         // HH:MM, 24-hour
  property bool alarmArmed: false
  property double alarmTargetAt: 0
  property string alarmTargetLabel: ""       // "TODAY 07:30" / "TOMORROW 07:30"
  property bool alarmRinging: false

  // --------------------------------------------------------------- heartbeat
  property double nowMs: Date.now()
  readonly property bool running: cdStatus === "running"
  readonly property bool needsHeartbeat: root.running || root.alarmArmed

  Timer {
    interval: 250
    repeat: true
    running: root.needsHeartbeat

    onTriggered: {
      root.nowMs = Date.now()
      root.checkDeadlines()
    }
  }

  readonly property double cdRemainingMs: root.running
    ? Math.max(0, root.cdEndAt - root.nowMs)
    : root.cdFrozenMs

  // --------------------------------------------------------------- formatting
  function hms(ms) {
    const total = Math.max(0, Math.round(ms / 1000))
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = total % 60

    return (hours < 10 ? "0" : "") + hours + ":"
      + (minutes < 10 ? "0" : "") + minutes + ":"
      + (seconds < 10 ? "0" : "") + seconds
  }

  readonly property string cdText: root.hms(root.cdRemainingMs)

  readonly property bool cdInputValid: root.parseDuration(root.cdInput) >= 0

  function parseDuration(text) {
    const match = /^([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})$/.exec(String(text).trim())
    if (match === null)
      return -1

    const hours = parseInt(match[1])
    const minutes = parseInt(match[2])
    const seconds = parseInt(match[3])

    if (hours > root.maxHours || minutes > 59 || seconds > 59)
      return -1

    return (hours * 3600 + minutes * 60 + seconds) * 1000
  }

  readonly property string cdStatusLabel: root.cdStatus === "running" ? "RUNNING"
    : root.cdStatus === "paused" ? "PAUSED"
    : root.cdStatus === "finished" ? "FINISHED"
    : root.cdInputValid ? "READY"
    : "ENTER HH:MM:SS"

  readonly property string alarmTimeValid: /^([01][0-9]|2[0-3]):([0-5][0-9])$/.test(root.alarmTime)
    ? "yes" : "no"

  readonly property string alarmStatusLabel: root.alarmRinging ? "RINGING"
    : root.alarmArmed ? (root.alarmTargetLabel === "" ? "ARMED" : "ARMED \u00B7 " + root.alarmTargetLabel)
    : root.alarmTimeValid === "yes" ? "OFF"
    : "ENTER HH:MM"

  // ------------------------------------------------------------- transitions
  function checkDeadlines() {
    if (root.cdStatus === "running" && root.cdRemainingMs <= 0) {
      // State first, then the side effects: this is what makes the event fire once.
      root.cdStatus = "finished"
      root.cdFrozenMs = 0
      root.persist()
      Notifier.send("Countdown finished", root.hms(root.durationMs) + " is up", "critical")
      SoundFx.play("error")
    }

    if (root.alarmArmed && root.alarmTargetAt > 0 && root.nowMs >= root.alarmTargetAt) {
      root.alarmArmed = false
      root.alarmRinging = true
      root.persist()
      Notifier.send("Alarm", root.alarmTime + " - time is up", "critical")
      SoundFx.play("error")
    }
  }

  // ------------------------------------------------------------ countdown API
  function setPreset(ms) {
    root.cdInput = root.hms(ms)
    root.durationMs = ms
    root.cdFrozenMs = ms
    root.cdStatus = "idle"
    root.cdEndAt = 0
    root.persist()
  }

  // Typed duration: keep what was typed (so an invalid entry stays visible) and apply
  // it only when it parses.
  function setDurationInput(text) {
    root.cdInput = String(text === undefined || text === null ? "" : text).slice(0, 8)

    const parsed = root.parseDuration(root.cdInput)
    if (parsed >= 0) {
      root.durationMs = parsed
      if (root.cdStatus === "idle" || root.cdStatus === "finished") {
        root.cdFrozenMs = parsed
        root.cdStatus = "idle"
      }
    }

    root.persist()
  }

  function start() {
    if (root.cdStatus === "running")
      return

    // Resume keeps the frozen remainder; a fresh start uses the typed duration.
    let remaining = root.cdFrozenMs
    if (root.cdStatus !== "paused" || remaining <= 0) {
      const parsed = root.parseDuration(root.cdInput)
      remaining = parsed >= 0 ? parsed : root.durationMs
    }

    if (remaining <= 0)
      return

    root.cdEndAt = Date.now() + remaining
    root.cdFrozenMs = remaining
    root.cdStatus = "running"
    root.nowMs = Date.now()
    root.persist()
  }

  function pause() {
    if (root.cdStatus !== "running")
      return

    root.cdFrozenMs = root.cdRemainingMs
    root.cdStatus = "paused"
    root.cdEndAt = 0
    root.persist()
  }

  function toggleRunning() {
    if (root.cdStatus === "running")
      root.pause()
    else
      root.start()
  }

  // Reset CLEARS the timer: the field goes back to 00:00:00 and nothing is left running. It used
  // to return to the last typed duration, which the owner read as "reset does nothing" (the field
  // kept showing the old value and looked stuck).
  function resetCountdown() {
    root.cdStatus = "idle"
    root.cdEndAt = 0
    root.cdInput = "00:00:00"
    root.durationMs = 0
    root.cdFrozenMs = 0
    root.persist()
  }

  // ---------------------------------------------------------------- alarm API
  function setAlarmTime(text) {
    root.alarmTime = String(text === undefined || text === null ? "" : text)
      .replace(/[^0-9:]/g, "")
      .slice(0, 5)

    if (root.alarmArmed)
      root.armAlarm()
    else
      root.persist()
  }

  function armAlarm() {
    if (root.alarmTimeValid !== "yes") {
      root.alarmArmed = false
      root.persist()
      return false
    }

    const parts = root.alarmTime.split(":")
    const now = new Date()
    // A time that already passed today is scheduled for tomorrow AND shown as such
    // ("TOMORROW 07:30") - never moved silently.
    let target = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
                          parseInt(parts[0]), parseInt(parts[1]), 0, 0)
    let label = "TODAY " + root.alarmTime

    if (target.getTime() <= Date.now()) {
      target = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1,
                        parseInt(parts[0]), parseInt(parts[1]), 0, 0)
      label = "TOMORROW " + root.alarmTime
    }

    root.alarmTargetAt = target.getTime()
    root.alarmTargetLabel = label
    root.alarmArmed = true
    root.alarmRinging = false
    root.nowMs = Date.now()
    root.persist()
    return true
  }

  function toggleAlarm() {
    if (root.alarmArmed) {
      root.alarmArmed = false
      root.alarmTargetAt = 0
      root.alarmRinging = false
      root.persist()
      return
    }

    root.armAlarm()
  }

  function dismissAlarm() {
    root.alarmRinging = false
    SoundFx.stop()
    root.persist()
  }

  // ------------------------------------------------------------- persistence
  function persist() {
    stateWriter.write(JSON.stringify({
      "mode": root.mode,
      "cdInput": root.cdInput,
      "durationMs": root.durationMs,
      "cdStatus": root.cdStatus,
      "cdEndAt": root.cdEndAt,
      "cdFrozenMs": root.cdFrozenMs,
      "alarmTime": root.alarmTime,
      "alarmArmed": root.alarmArmed,
      "alarmTargetAt": root.alarmTargetAt,
      "alarmTargetLabel": root.alarmTargetLabel,
      "alarmRinging": root.alarmRinging
    }))
  }

  // Written through a command: the state directory does not exist on a fresh install,
  // and the value travels as an argument so nothing can break the script.
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
    id: timerFile

    path: root.stateFile
    blockLoading: true
    watchChanges: false
    printErrors: false

    onLoaded: {
      const text = timerFile.text().trim()
      if (text === "")
        return

      let stored = null
      try {
        stored = JSON.parse(text)
      } catch (error) {
        stored = null
      }

      if (!stored)
        return

      root.mode = stored.mode === "alarm" ? "alarm" : "countdown"
      root.cdInput = String(stored.cdInput === undefined ? root.cdInput : stored.cdInput)
      root.durationMs = Number(stored.durationMs) > 0 ? Number(stored.durationMs) : root.durationMs
      root.cdFrozenMs = Number(stored.cdFrozenMs) >= 0 ? Number(stored.cdFrozenMs) : root.durationMs
      root.cdEndAt = Number(stored.cdEndAt) || 0
      root.cdStatus = ["idle", "running", "paused", "finished"].indexOf(stored.cdStatus) >= 0
        ? stored.cdStatus : "idle"

      // A countdown that expired while the shell was not running is shown as finished,
      // without firing: the shell was not there to notify.
      if (root.cdStatus === "running" && root.cdEndAt <= Date.now()) {
        root.cdStatus = "finished"
        root.cdFrozenMs = 0
      }

      root.alarmTime = String(stored.alarmTime === undefined ? root.alarmTime : stored.alarmTime)
      root.alarmTargetAt = Number(stored.alarmTargetAt) || 0
      root.alarmTargetLabel = String(stored.alarmTargetLabel === undefined ? "" : stored.alarmTargetLabel)
      root.alarmRinging = stored.alarmRinging === true
      root.alarmArmed = stored.alarmArmed === true

      // An alarm that was due while the shell was down: never silently lost.
      if (root.alarmArmed && root.alarmTargetAt > 0 && root.alarmTargetAt <= Date.now()) {
        root.alarmArmed = false
        root.alarmRinging = true
        root.persist()
        Notifier.send("Alarm", root.alarmTime + " was due while Quickshell was not running",
                      "critical")
      }

      root.nowMs = Date.now()
      console.log("TIMER restored: mode=" + root.mode + " cd=" + root.cdStatus
                  + " input=" + root.cdInput + " alarm=" + root.alarmTime
                  + " armed=" + root.alarmArmed + " ringing=" + root.alarmRinging)
    }

    onLoadFailed: (error) => {
    }
  }
}
