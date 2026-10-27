import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs.services
import "../theme"

// Notification toasts, stacked in the top-centre of the pinned primary output.
//
// One window per screen, but only the screen the stack belongs to (Notifications.targetScreen)
// maps it - a notification must not appear twice on a two-monitor desk. The surface is a fixed
// box with a mask over the card column, so the empty part is click-through, and it is unmapped
// the moment the stack empties.
//
// Card rules (owner's decisions): square, flat, theme tokens only; the sending app's real icon
// when one resolves; NO "notify-send"/"Quickshell" label; plain text (markup is stripped); a
// normal toast leaves on its own, a critical one waits for a click.
PanelWindow {
  id: root

  readonly property Theme theme: Theme { }
  readonly property color secondaryText: "#bdae93"

  // One dial for the card's overall size, 15% over the original tokens.
  //
  // A wider-only card read as squat: the box grew but the text did not, so the card got flatter
  // looking instead of bigger. Everything the card draws - width, fonts, padding, icon, action
  // chips - is multiplied by this factor, so the shape is preserved and the diagonal is what
  // changes. Retune the card here, not at the individual call sites.
  readonly property real scaleFactor: 1.10

  // The box keeps its original 380 width while the type scales: at 418 the card read as
  // unnecessarily long. Only the vertical bulk and the text grew.
  readonly property int toastWidth: 380
  // Room for five tall cards (2 title lines + 3 body lines + buttons) and the gaps between them.
  readonly property int stackHeight: Math.round(700 * root.scaleFactor)

  readonly property int titlePx: Math.round((root.theme.fontSize + 2) * root.scaleFactor)
  // +1 over the scaled token: at 1.10 the body read a size too small to the owner, while the
  // title was fine. Hierarchy still comes from weight and colour, so the two do not compete.
  readonly property int bodyPx: Math.round(root.theme.fontSize * root.scaleFactor) + 1
  // The inline platform label sits between the old meta size and the body size: at metaPx
  // (12) the owner could read it but had to look for it. It has to stay smaller than the
  // title (18) so the sender is still the first thing the eye lands on.
  readonly property int platformPx: Math.round((root.theme.fontSize - 3) * root.scaleFactor) + 3
  readonly property int closePx: Math.round((root.theme.fontSize + 1) * root.scaleFactor)
  readonly property int padPx: Math.round(12 * root.scaleFactor)
  readonly property int gapPx: Math.round(10 * root.scaleFactor)
  readonly property int iconPx: Math.round(28 * root.scaleFactor)
  readonly property int chipHeight: Math.round(28 * root.scaleFactor)
  readonly property int chipPadX: Math.round(24 * root.scaleFactor)

  // The output this toast belongs to, handed over by shell.qml. `screenName` is what decides
  // whether the stack shows here; `targetScreen` only supplies geometry.
  //
  // NOTE: deliberately NOT using the layer surface's own `screen` for that decision. It is only
  // resolved while the surface is mapped, so gating `visible` on it loops (mine -> visible ->
  // screen -> mine) and the card silently never appears.
  property string screenName: ""
  property var targetScreen: null

  readonly property bool mine: root.screenName !== ""
    && Notifications.targetScreen === root.screenName

  visible: Notifications.hasVisible && root.mine

  exclusionMode: ExclusionMode.Ignore

  anchors.top: true
  anchors.left: true
  margins.top: root.theme.popupTop
  margins.left: root.targetScreen
    ? Math.round((root.targetScreen.width - root.toastWidth) / 2)
    : root.theme.margins

  color: "transparent"

  implicitWidth: root.toastWidth
  // Constant, deliberately: a surface that grows with its cards maps with a stale buffer and the
  // tallest card (title + body + action buttons) ended up invisible. The mask below keeps the
  // unused part of the surface click-through, so the fixed height costs nothing.
  implicitHeight: root.stackHeight

  mask: Region {
    item: column
  }

  Column {
    id: column

    width: parent.width
    spacing: root.gapPx

    Repeater {
      model: Notifications.visible

      delegate: NotificationCard {
        required property var modelData

        notification: modelData
        width: column.width
      }
    }
  }

  // ------------------------------------------------------------------- card
  component NotificationCard: Rectangle {
    id: card

    property var notification: null

    readonly property bool critical: card.notification !== null
      && card.notification.urgency === NotificationUrgency.Critical
    readonly property int timeoutMs: Notifications.timeoutFor(card.notification)
    readonly property string source: Notifications.sourceLabel(card.notification)
    readonly property string summaryText:
      Notifications.cleanText(card.notification ? card.notification.summary : "")
    readonly property string bodyText:
      Notifications.cleanText(card.notification ? card.notification.body : "")

    // Actions come as a list of NotificationAction; the "default" one belongs to the whole card,
    // the rest become buttons (at most two, so a chatty app cannot grow the card forever).
    readonly property var actionList: {
      const list = card.notification ? card.notification.actions : null

      if (!list)
        return []

      const out = []

      for (let i = 0; i < list.length; ++i)
        out.push(list[i])

      return out
    }

    readonly property var defaultAction: {
      for (let i = 0; i < card.actionList.length; ++i) {
        if (card.actionList[i].identifier === "default")
          return card.actionList[i]
      }

      return null
    }

    // Two kinds of action are dropped:
    //  - "Settings": Chromium appends it to every web notification (opens the site's notification
    //    permissions), so it lands on a WhatsApp/Edge toast as a mystery button.
    //  - "Reply"/"Balas": the server advertises inline reply as UNSUPPORTED, so this action cannot
    //    do what it says - it only opens the app. The owner never answers from a toast, so the
    //    button is noise and the space is better spent on the message.
    readonly property var buttonActions: card.actionList.filter(function (action) {
      if (action.identifier === "default")
        return false

      const label = String(action.text).trim()

      if (/^(settings?|setelan|pengaturan|preferences|options|more)$/i.test(label))
        return false

      if (/^(reply|replies|balas|jawab|quick reply)$/i.test(label))
        return false

      const id = String(action.identifier).trim()

      return !/^settings?$/i.test(id) && !/reply|balas/i.test(id)
    }).slice(0, 2)

    // Sender icons are file paths or themed icon names. Remote http(s) images are deliberately
    // ignored: a web notification must not make the desktop fetch something on its own.
    //
    // Quickshell turns a themed app icon into `image://icon/<name>`, and that URL happily resolves
    // to nothing - Qt then paints its missing-texture placeholder. So the name is validated with
    // Quickshell.iconPath() first, and anything that does not exist falls back to the bell glyph.
    readonly property string iconSource: {
      const n = card.notification

      if (!n)
        return ""

      const image = String(n.image === undefined ? "" : n.image)
      const icon = String(n.appIcon === undefined ? "" : n.appIcon)
      const prefix = "image://icon/"

      if (image.indexOf(prefix) === 0) {
        const path = Quickshell.iconPath(image.substring(prefix.length), true)

        return path === undefined || path === null ? "" : String(path)
      }

      if (image !== "" && image.indexOf("http") !== 0)
        return image

      if (icon !== "") {
        const path = Quickshell.iconPath(icon, true)

        return path === undefined || path === null ? "" : String(path)
      }

      return ""
    }

    // A resolved icon can still fail to decode (the theme has no such icon, the file is gone).
    // Without this flag Qt paints its "missing texture" placeholder, which looks like a bug.
    property bool iconFailed: false

    readonly property bool showIcon: card.iconSource !== "" && !card.iconFailed

    implicitHeight: content.implicitHeight + root.padPx * 2

    color: root.theme.panel
    border.width: 2
    border.color: card.critical ? root.theme.warning : root.secondaryText
    radius: 0

    // Detach from the visible list BEFORE the object can be closed: closing destroys the C++
    // notification, and any reference touched afterwards is a dangling pointer.
    function dismiss() {
      Notifications.close(card.notification)
    }

    function activate() {
      const action = card.defaultAction
      const target = card.notification

      Notifications.remove(target)

      // The app closes its own notification after a default action; dismissing it here too would
      // be a second call on an object the server may already have dropped.
      if (action)
        action.invoke()
      else
        Notifications.close(target)
    }

    // Declared before the content so the text sits above it: the body click still reaches this
    // MouseArea (plain items do not consume presses), while the action buttons below declare
    // their own MouseArea and therefore win.
    MouseArea {
      id: body

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: card.activate()
    }

    Timer {
      id: life

      interval: card.timeoutMs
      repeat: false
      // Hovering pauses the countdown: a card must not vanish while it is being read.
      running: card.timeoutMs > 0 && !body.containsMouse
      onTriggered: card.dismiss()
    }

    Connections {
      target: card.notification

      function onClosed() {
        Notifications.remove(card.notification)
      }

      // A replaces_id update rewrites the same object: new text deserves a full timeout.
      function onSummaryChanged() {
        if (card.timeoutMs > 0)
          life.restart()
      }

      function onBodyChanged() {
        if (card.timeoutMs > 0)
          life.restart()
      }
    }

    // Anchored on three sides only. With anchors.fill the row's height would be forced from the
    // card while the card's implicitHeight is derived from the row - a circular dependency that
    // makes the card height (and the text inside it) unreliable.
    RowLayout {
      id: content

      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: root.padPx
      anchors.leftMargin: root.padPx
      anchors.rightMargin: root.padPx
      spacing: root.gapPx

      // ---------------------------------------------------------------- icon
      Item {
        Layout.preferredWidth: root.iconPx
        Layout.preferredHeight: root.iconPx
        Layout.alignment: Qt.AlignTop

        Image {
          anchors.fill: parent
          visible: card.showIcon

          onStatusChanged: {
            if (status === Image.Error)
              card.iconFailed = true
          }

          source: card.iconSource
          sourceSize.width: root.iconPx
          sourceSize.height: root.iconPx
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: !card.showIcon

          text: "\uf0f3"
          color: root.secondaryText

          font.family: root.theme.fontFamily
          font.pixelSize: root.titlePx
          font.weight: Font.Bold
        }
      }

      // --------------------------------------------------------------- text
      ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: 100000
        spacing: 2

        // Header row: sender and platform share one line.
        //
        // The platform used to sit on its own line above the title, which at this width read as a
        // tiny stacked label - app, then sender, then message, three levels of hierarchy for a
        // two-line chat - and made every chat card a line taller. Inline it stays informative
        // (the app name is still spelled out, not only implied by an icon that may not resolve)
        // and costs no extra height. Right-aligned and dim on purpose: it qualifies the sender,
        // it is not a second title.
        RowLayout {
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          spacing: 8

          Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 100000

            text: card.summaryText
            textFormat: Text.PlainText
            color: root.theme.fg

            font.family: root.theme.fontFamily
            font.pixelSize: root.titlePx
            font.weight: Font.Bold
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          Text {
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            Layout.topMargin: 2
            Layout.maximumWidth: Math.round(root.toastWidth * 0.4)
            visible: card.source !== ""

            text: card.source
            // Never let a client's markup be interpreted: AutoText would happily render HTML.
            textFormat: Text.PlainText
            // Title colour, not body colour: the label belongs to the header row, and the size gap
            // (15 vs 18) plus the weight (DemiBold vs Bold) is what keeps the sender on top. A
            // third tone would make the card read as three competing colours.
            color: root.theme.fg

            font.family: root.theme.fontFamily
            font.pixelSize: root.platformPx
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          visible: card.bodyText !== ""

          text: card.bodyText
          textFormat: Text.PlainText
          color: root.secondaryText

          font.family: root.theme.fontFamily
          // Same size as the title (hierarchy comes from weight and colour, not from shrinking
          // the message). The owner read the body as too small at fontSize - 2.
          font.pixelSize: root.bodyPx
          wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          maximumLineCount: 3
          elide: Text.ElideRight
        }

        // ------------------------------------------------------------ actions
        // A plain Row rather than a RowLayout: the chips have fixed sizes, so no negotiation is
        // needed and the row stays exactly as tall as they are.
        Row {
          Layout.fillWidth: true
          Layout.maximumWidth: 100000
          Layout.topMargin: 4
          visible: card.buttonActions.length > 0
          spacing: 8

          Repeater {
            model: card.buttonActions

            delegate: Rectangle {
              id: actionButton

              required property var modelData

              // 24 px was unreadable, 32 px read as bulky: 28 px with 24 px of padding is the
              // size the owner settled on. Both scale with the card (see scaleFactor).
              width: actionLabel.implicitWidth + root.chipPadX
              height: root.chipHeight

              color: "transparent"
              radius: 0
              border.width: 1
              border.color: actionMouse.containsMouse ? root.theme.accent : root.secondaryText

              Text {
                id: actionLabel

                anchors.centerIn: parent

                text: String(actionButton.modelData.text)
                color: actionMouse.containsMouse ? root.theme.accent : root.theme.fg

                font.family: root.theme.fontFamily
                font.pixelSize: root.bodyPx
                font.weight: Font.DemiBold
              }

              MouseArea {
                id: actionMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                  actionButton.modelData.invoke()
                  card.dismiss()
                }
              }
            }
          }
        }
      }

      // --------------------------------------------------------------- close
      Text {
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: root.padPx

        text: "\u00D7"
        color: body.containsMouse ? root.theme.fg : root.secondaryText
        opacity: body.containsMouse ? 1 : 0

        font.family: root.theme.fontFamily
        font.pixelSize: root.closePx
        font.weight: Font.Bold

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: card.dismiss()
        }
      }
    }
  }
}
