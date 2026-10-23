pragma Singleton

import Quickshell
import QtQuick

// Popup state. Exactly ONE popup is open across the whole shell: opening one closes
// whatever was open, which is what keeps panels from ever being on screen in a stale
// combination. Popup windows are plain layer surfaces (no grab), so bar clicks keep
// working while one is open; the shield in shell.qml closes it on outside clicks.
//
// `payload` is WHICH TAB the shared popup shows ("date" | "clock" | "weather"): the
// bar's three segments all open the same popup and only differ in the tab they ask for.
Singleton {
  id: root

  property string activeName: ""
  property string activeScreen: ""
  property string payload: ""

  // Geometry of the region the click shield must leave open for the active popup.
  // The popup claims its own size the moment it becomes visible, so the pass-through
  // region is never larger than the popup itself.
  property int slotWidth: 805
  property int slotHeight: 376

  // The popup sits under the middle of the bar, so its shield region stays centered.
  property bool slotCentered: false

  // Launcher only: it belongs in the middle of the screen, not under the bar, so its shield
  // region is centered vertically as well.
  property bool slotVerticalCenter: false

  function open(screenName, name, tab) {
    root.activeName = name
    root.activeScreen = screenName

    if (tab !== undefined && tab !== "")
      root.payload = tab
  }

  // Clicking the segment that is already open ON THAT TAB closes the popup; clicking a
  // different segment switches tabs and keeps the popup open (same popup, other tab).
  function toggle(screenName, name, tab) {
    if (root.activeScreen === screenName && root.activeName === name) {
      if (tab === undefined || tab === "" || tab === root.payload) {
        root.close(screenName)
        return
      }

      root.payload = tab
      return
    }

    root.open(screenName, name, tab)
  }

  // Used by the in-popup tab buttons: switch the tab, never close the popup.
  function setPayload(tab) {
    if (tab !== undefined && tab !== "")
      root.payload = tab
  }

  function claimSlot(width, height, centered, verticalCenter) {
    root.slotWidth = width
    root.slotHeight = height
    root.slotCentered = centered === true
    root.slotVerticalCenter = verticalCenter === true
  }

  function close(screenName) {
    if (root.activeScreen === screenName) {
      root.activeName = ""
      root.activeScreen = ""
      root.payload = ""
    }
  }

  function closeAll() {
    root.activeName = ""
    root.activeScreen = ""
    root.payload = ""
  }

  function screenHasActive(screenName) {
    return root.activeScreen === screenName && root.activeName !== ""
  }

  function isOpen(screenName, name) {
    return root.activeScreen === screenName && root.activeName === name
  }
}
