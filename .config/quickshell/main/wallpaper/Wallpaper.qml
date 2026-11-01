import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// The desktop wallpaper, drawn by the shell itself.
//
// One layer-shell surface per output on the BACKGROUND layer. This is what the big shells do --
// GNOME and KDE paint their own wallpaper, and both Noctalia (LayerShellLayer::Background per output)
// and Caelestia (WlrLayershell.layer: WlrLayer.Background inside a Screen Variants) do exactly this.
//
// Why not a wallpaper daemon (swww/awww/hyprpaper): a daemon is a second process that has to start
// after the compositor, own a socket, and re-apply on every output that appears late. Every one of
// those steps is a race, which is why a daemon setup always ends up with retries, sleeps and a
// "fallback if nothing happened for a few seconds". None of that exists here: the surface is created
// with the shell, each screen has its own instance, and a monitor connected later simply gets a new
// one.
//
// TRANSITION: assigning a new `source` to an Image replaces its pixels in one frame, so the surface
// was empty for as long as the incoming file took to decode - a split second of bare palette
// background on every wallpaper change. Two images close that gap: `settled` keeps painting the
// previous image, `incoming` decodes the new one underneath opacity 0, and only when it reports Ready
// does it dissolve over the old one. Nothing is ever unpainted, so there is no blank frame at all.
//
// INTERRUPTION: a fade can be overtaken - Ctrl+Tab pressed twice, or a theme switch during a
// transition. The image that is halfway faded in is COMMITTED first (promoted to `settled` at full
// opacity) before the next one starts, because simply restarting the animation resets it to opacity 0
// and drops the desktop back to the image underneath: that is what looked like an abruptly truncated
// fade, and why a fast second press appeared to keep the same wallpaper.
Variants {
  model: Quickshell.screens

  delegate: Component {
    PanelWindow {
      id: surface

      required property var modelData

      readonly property Theme theme: Theme {}

      screen: modelData

      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "quickshell-wallpaper"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // The palette's own background, so the first frame of a session is the theme colour while the
      // image decodes instead of a black flash.
      color: ThemeState.bg

      // Path currently painted by `settled`. Empty until the first image is on screen.
      property string shownPath: ""
      property bool fadePending: false

      // Promote whatever is in `incoming` to the settled image. Used when a fade finishes and when a
      // new wallpaper interrupts one: assigning an already decoded source is a same-frame swap, so
      // there is no gap between "the blend I was looking at" and "that image, fully opaque".
      function commit() {
        if (incoming.source.toString() !== "")
          settled.source = incoming.source;

        incoming.opacity = 0;
        surface.fadePending = false;
      }

      function adopt(path, source) {
        if (path === "" || path === surface.shownPath)
          return;

        // Finish the transition that is already running instead of throwing it away.
        if (surface.fadePending || fade.running)
          surface.commit();

        // First image of the session, or the reduce-motion switch: paint it straight away, because
        // fading in the login wallpaper from the palette colour is a delay, not a nicety.
        if (settled.source.toString() === "" || surface.theme.wallpaperFade === 0) {
          settled.source = source;
          surface.shownPath = path;
          return;
        }

        surface.shownPath = path;
        surface.fadePending = true;
        incoming.source = source;

        // `source` may already be cached, in which case status is Ready before the next frame and
        // onStatusChanged never fires. Starting from the current status as well covers that.
        if (incoming.status === Image.Ready)
          fade.restart();
      }

      Connections {
        target: WallpaperState

        function onPathChanged() {
          surface.adopt(WallpaperState.path, WallpaperState.source);
        }
      }

      Component.onCompleted: surface.adopt(WallpaperState.path, WallpaperState.source)

      // The image being looked at. Never blanked: it holds the old wallpaper until a new one has been
      // fully decoded and is at full opacity.
      Image {
        id: settled

        anchors.fill: parent

        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }

      // The incoming image, invisible until it is ready.
      Image {
        id: incoming

        anchors.fill: parent

        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: 0

        onStatusChanged: {
          if (status === Image.Ready && surface.fadePending)
            fade.restart();
          // A broken file must not leave the surface waiting for a fade that never starts; the
          // settled image simply stays on screen.
          if (status === Image.Error)
            surface.fadePending = false;
        }
      }

      NumberAnimation {
        id: fade

        target: incoming
        property: "opacity"
        from: 0
        to: 1
        duration: surface.theme.wallpaperFade
        easing.type: Easing.InOutQuad

        onFinished: surface.commit()
      }
    }
  }
}
