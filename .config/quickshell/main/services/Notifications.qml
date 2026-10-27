pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The desktop's notification daemon, inside the shell.
//
// Quickshell's NotificationServer claims org.freedesktop.Notifications on the session bus, so
// anything that speaks the freedesktop protocol (notify-send, libnotify apps, Chromium web
// apps, chat clients) lands here and is rendered by popups/NotificationToast.qml. There is no
// one process: one shell, one owner of the bus name.
//
// Policy, all of it decided by the owner:
//  - normal / low toasts expire on their own (8s / 4s), a sender may ask for longer (capped at
//    30s), hovering pauses the countdown.
//  - CRITICAL toasts are sticky: they stay until the card is clicked. The shell's own alarm and
//    countdown go through this path, so a finished timer always waits for acknowledgement.
//  - No do-not-disturb mode on purpose (the owner does not want one), so every notification is
//    shown.
//  - Markup, hyperlinks, body images and inline reply are advertised as UNSUPPORTED: clients
//    then send plain text, which is what keeps a toast clean (no HTML tags leaking into the
//    card, no fake buttons).
//  - At most five cards are on screen; a sixth retires the oldest.
//
// LIFETIME RULE: `visible` holds live Notification objects, and it is the ONLY place that does.
// Quickshell destroys the C++ notification once it is closed, so an object kept anywhere else
// (a history list, a delegate's copy) becomes a dangling pointer and the next D-Bus call crashes
// the whole shell - that is exactly the SIGSEGV this file used to cause. Anything that must
// outlive a toast is stored as plain data by snapshot().
Singleton {
  id: root

  readonly property int maxVisible: 5
  readonly property int recentLimit: 20
  readonly property int lowMs: 4000
  readonly property int normalMs: 8000
  readonly property int maxSenderTimeoutMs: 30000

  // Newest first, live objects only, pruned on `closed`.
  property var visible: []
  // Newest first, plain data ({ appName, summary, body, urgency, at }) - never a Notification.
  property var recent: []
  // Which output the current stack belongs to (resolved while the stack was empty).
  property string targetScreen: ""

  // The output toasts open on: the primary monitor, by connector name.
  //
  // This used to follow keyboard focus (ScreenFocus). The owner glances at the secondary
  // screen often, but his hands go back to the primary one ~95% of the time, so a toast that
  // opened on the other monitor was regularly looked for and never found. Pinning removes
  // that ambiguity. A renamed or unplugged output falls back to the widest screen (here that
  // is the primary), so a toast is never left without a screen to open on.
  readonly property string pinnedScreen: "DP-2"

  readonly property bool hasVisible: root.visible.length > 0

  NotificationServer {
    id: server

    bodySupported: true
    bodyMarkupSupported: false
    bodyHyperlinksSupported: false
    bodyImagesSupported: false
    actionsSupported: true
    actionIconsSupported: false
    imageSupported: true
    inlineReplySupported: false
    persistenceSupported: false

    onNotification: function (notification) {
      root.receive(notification)
    }
  }

  // ------------------------------------------------------------------ incoming
  function receive(notification) {
    if (!notification)
      return

    // THE critical line: the server hands the notification over UNTRACKED, and an untracked
    // notification is discarded (its C++ object destroyed) as soon as this handler returns.
    // Without this, every reference we keep - the visible stack, a card's binding, a history
    // entry - points at freed memory: the card renders empty and the next D-Bus call crashes
    // the shell with SIGSEGV.
    notification.tracked = true

    root.recent = [root.snapshot(notification)].concat(root.recent).slice(0, root.recentLimit)

    // Audible cue: the soft sample for ordinary traffic, the negative one for failures.
    // for anything critical. The shell's own alarm/countdown is skipped because TimerService plays
    // its own sample - two players at once would cut each other off.
    if (String(notification.appName) !== "Quickshell")
      SoundFx.play(notification.urgency === NotificationUrgency.Critical ? "error" : "positive")

    // The stack belongs to the pinned output; later cards join it there, so a notification
    // cannot jump monitors mid-read.
    if (root.visible.length === 0)
      root.targetScreen = root.pinnedScreenName()

    // Make room: retire the oldest. Detach it from the list BEFORE dismissing it, because
    // dismissing can close (and therefore destroy) the object.
    let next = root.visible

    if (next.length >= root.maxVisible) {
      const oldest = next[next.length - 1]
      next = next.slice(0, next.length - 1)

      if (oldest && oldest.dismiss)
        oldest.dismiss()
    }

    root.visible = [notification].concat(next)

    console.log("NOTIFY in: app=" + notification.appName + " urgency=" + notification.urgency
                + " summary=" + notification.summary)
  }

  // Called by the card when the notification ends (click, timeout, or the sending app).
  // Detaching first keeps every other reference (the Repeater, the cards) off a dead object.
  function remove(notification) {
    const index = root.visible.indexOf(notification)

    if (index < 0)
      return

    const next = root.visible.slice()
    next.splice(index, 1)
    root.visible = next

    if (next.length === 0)
      root.targetScreen = ""
  }

  // What a card calls when the user closed it: leave the list, then tell the sender.
  function close(notification) {
    root.remove(notification)

    if (notification && notification.dismiss)
      notification.dismiss()
  }

  function dismissAll() {
    const list = root.visible.slice()

    root.visible = []
    root.targetScreen = ""

    for (let i = 0; i < list.length; ++i) {
      if (list[i] && list[i].dismiss)
        list[i].dismiss()
    }
  }

  function pinnedScreenName() {
    const screens = Quickshell.screens

    for (let i = 0; i < screens.length; ++i) {
      if (String(screens[i].name) === root.pinnedScreen)
        return root.pinnedScreen
    }

    let widest = screens.length > 0 ? screens[0] : null

    for (let i = 1; i < screens.length; ++i) {
      if (widest && screens[i].width > widest.width)
        widest = screens[i]
    }

    return widest ? String(widest.name) : ""
  }

  function snapshot(notification) {
    return {
      "appName": String(notification.appName === undefined ? "" : notification.appName),
      "summary": root.cleanText(notification.summary),
      "body": root.cleanText(notification.body),
      "urgency": notification.urgency,
      "at": Date.now()
    }
  }

  // ---------------------------------------------------------------- timings
  // Sticky = 0. The sender's own expire timeout wins when it is longer than ours, capped so a
  // chatty app cannot park a card on screen for minutes.
  function timeoutFor(notification) {
    if (!notification)
      return 0

    if (notification.urgency === NotificationUrgency.Critical)
      return 0

    const asked = Number(notification.expireTimeout)

    if (asked === 0)
      return 0

    const base = notification.urgency === NotificationUrgency.Low ? root.lowMs : root.normalMs

    if (!(asked > 0))
      return base

    return Math.min(Math.max(base, asked), root.maxSenderTimeoutMs)
  }

  // ------------------------------------------------------------------ text
  // Clients that ignore "no markup" still send HTML. Strip tags and decode the few entities
  // that would otherwise show up literally, because the owner asked for a clean card.
  function cleanText(value) {
    return String(value === undefined || value === null ? "" : value)
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/p>/gi, "\n")
      .replace(/<[^>]*>/g, "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&#0?39;/g, "'")
      .replace(/&apos;/g, "'")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .trim()
  }

  // The tiny "who sent this" label. Hidden for plain-CLI and for the shell's own traffic, which
  // is what removes the ugly "notify-send" / "Quickshell" line.
  function sourceLabel(notification) {
    if (!notification)
      return ""

    const name = String(notification.appName === undefined ? "" : notification.appName).trim()
    const lower = name.toLowerCase()

    if (name === "" || lower === "notify-send" || lower === "quickshell"
        || lower === "libnotify" || lower === "unknown")
      return ""

    return name
  }
}
