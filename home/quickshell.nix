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
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
