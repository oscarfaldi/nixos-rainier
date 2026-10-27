// Quickshell lock screen entry point.
//
// Wayland's ext-session-lock-v1 means the compositor paints nothing else until this client releases
// the lock, so this must never fail half-way: if the UI breaks, the session stays locked on a black
// screen. That is why the surface carries a solid colour behind everything.
//
// The client exits itself as soon as the password is accepted, so "a lock instance is running" always
// means "the session is locked". Kill switch (from a TTY or SSH): pkill -f 'quickshell.*quickshell/lock'.
//
// QS_LOCK_TEST=1 renders the same content as an ordinary full-screen surface instead of locking, so
// the design can be reviewed without locking the session.
//
// NOTE: WlSessionLockSurface's `screen`, `width`, `height` and `data` are READ-ONLY - Quickshell
// instantiates the surface itself, once per output. Assigning `screen` (or wrapping it in a
// Repeater) is a load error, not a per-screen layout.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property bool testMode: Quickshell.env("QS_LOCK_TEST") === "1"

  Component {
    id: lockComponent

    WlSessionLock {
      id: lock
      locked: true

      WlSessionLockSurface {
        color: "#000000"

        LockContent {
          anchors.fill: parent
          onUnlocked: {
            // Release first, then exit. A dying client also releases the lock, but releasing
            // explicitly means the compositor is never left guessing if the exit is delayed.
            lock.locked = false;
            quitTimer.restart();
          }
        }
      }
    }
  }

  Component {
    id: testComponent

    PanelWindow {
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      LockContent {
        anchors.fill: parent
        onUnlocked: Qt.quit()
      }
    }
  }

  Loader {
    sourceComponent: root.testMode ? testComponent : lockComponent
  }

  // The lock client must NOT keep running after it unlocks. If it does, `qs-lock` finds a live
  // process on the next request and returns immediately (it never kills a live instance, because that
  // would release the session lock for a moment) - so the second lock silently does nothing. That is
  // what left a session unlocked after resume from suspend.
  //
  // Qt.quit() is the call that works on this Quickshell version; Quickshell.quit() does not exist and
  // fails with "Property 'quit' ... is not a function". The short delay lets the release land first.
  Timer {
    id: quitTimer
    interval: 150
    onTriggered: Qt.quit()
  }
}
