pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Sound playback, deliberately separate from notifications: a notification can be
// delivered while the sound is muted, and the sound can be tested on its own.
//
// Assets and player: the notification sounds this desktop ships with. They run
// `pw-play /home/oscarfaldi/System/assets/sounds/positive.ogg` - so nothing new is
// installed. positive.ogg = "something finished", negative.ogg = "something failed".
Singleton {
  id: root

  readonly property string soundDir: Quickshell.env("HOME") + "/System/assets/sounds"
  readonly property string player: "pw-play"

  property string lastError: ""
  property bool playing: false
  // Which sample the player was last asked for, so the log names the real file instead of
  // always claiming positive.ogg.
  property string lastKind: "positive"

  function fileFor(kind) {
    return root.soundDir + (kind === "error" ? "/negative.ogg" : "/positive.ogg")
  }

  // A short notification sample: it ends on its own, so "stop" only matters for a
  // dismiss while it is still running.
  function play(kind) {
    const file = root.fileFor(kind)
    root.lastKind = kind
    player.running = false
    player.command = [root.player, file]
    player.running = true
  }

  function stop() {
    stopper.running = false
    stopper.running = true
  }

  Process {
    id: player

    onStarted: root.playing = true

    onExited: (code, status) => {
      root.playing = false
      if (code !== 0) {
        root.lastError = root.player + " exited with " + code
        console.log("SOUND failed:", root.lastError, "(player present?)")
      } else {
        // success is silent on purpose: this fires for every toast
      }
    }
  }

  // The pattern is narrow on purpose: only this shell's own notification samples.
  Process {
    id: stopper

    command: ["pkill", "-f", "pw-play .*/assets/sounds/"]

    onExited: (code, status) => {
      if (code === 0)
        root.playing = false
    }
  }
}
