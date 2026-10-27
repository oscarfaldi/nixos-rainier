{ config, pkgs, ... }:

# The shell runs as a systemd user service instead of a bare `spawn-at-startup`.
#
# Why: niri starts it once and never looks again, so a crash left the session without a bar until the
# compositor restarted. Under systemd a crash is a restart, `journalctl --user -u quickshell` has the
# output, and restarting it is `systemctl --user restart quickshell`.
#
# The unit gets its environment from niri, which owns WAYLAND_DISPLAY and NIRI_SOCKET: see the spawn
# line in .config/niri/config.kdl, which imports them into the user manager before starting this.
{
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell shell: bar, popups, launcher, notifications";

      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];

      # A crash loop should keep retrying. Giving up would leave a session with no bar at all.
      StartLimitIntervalSec = 0;
    };

    Service = {
      # -n: exit immediately when another instance of this config is already running. Two live
      # instances draw two bars over each other (that happened once, from a shell started by hand).
      ExecStart = "${pkgs.quickshell}/bin/qs -n -p %h/System/.config/quickshell/main";
      Restart = "always";
      RestartSec = 1;

      # Qt only decodes an image format when its plugin is on QT_PLUGIN_PATH. The quickshell wrapper
      # brings qtbase, qtsvg and qtwayland, but not qtimageformats, so the .webp wallpapers were
      # rejected with "Error decoding: Unsupported image format" and the wallpaper window stayed
      # empty. The wrapper PREPENDS its own directories and keeps whatever is already there, so this
      # adds webp/tiff/icns support without dropping quickshell's own plugins.
      Environment = [ "QT_PLUGIN_PATH=${pkgs.qt6.qtimageformats}/lib/qt-6/plugins" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
