pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The single notification adapter for the whole shell.
//
// Everything that wants to notify the desktop goes through send() here. The delivery is
// `notify-send`, i.e. a real freedesktop client call, which now lands in the shell's OWN
// NotificationServer (services/Notifications.qml). That is deliberate: the shell's alarm and
// countdown take exactly the same path as a notification from Chromium or a chat app, so there
// is no privileged side door and the toast rendering is tested by the shell's own traffic.
//
// Notifications are queued because one Process can only carry one command at a
// time: a countdown finishing at the same moment as an alarm must not swallow
// either message.
Singleton {
  id: root

  // Kept for the report and for wiring an IPC probe later; a failed notify-send is
  // logged, never silently ignored.
  property int sentCount: 0
  property string lastError: ""

  property var queue: []

  function send(title, body, urgency) {
    const level = (urgency === undefined || urgency === "") ? "normal" : String(urgency)
    root.queue = root.queue.concat([{ "title": String(title), "body": String(body), "level": level }])
    root.pump()
  }

  function pump() {
    if (sender.running || root.queue.length === 0)
      return

    const next = root.queue[0]
    root.queue = root.queue.slice(1)
    // No x-canonical-private-synchronous hint: it makes the daemon REPLACE the
    // previous notification, so an alarm could silently overwrite an unrelated
    // countdown message and never show up in the history.
    sender.command = ["notify-send", "-a", "Quickshell", "-u", next.level,
                      next.title, next.body]
    sender.running = true
  }

  Process {
    id: sender

    onExited: (code, status) => {
      if (code === 0) {
        root.sentCount = root.sentCount + 1
        // keep a counter only; no logging, this runs for every toast
      } else {
        root.lastError = "notify-send exited with " + code
        console.log("NOTIFY failed:", root.lastError)
      }

      root.pump()
    }
  }
}
