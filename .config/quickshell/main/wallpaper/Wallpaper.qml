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
Variants {
  model: Quickshell.screens

  delegate: Component {
    PanelWindow {
      required property var modelData

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

      Image {
        anchors.fill: parent

        source: WallpaperState.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }
  }
}
