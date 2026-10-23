{ pkgs, ... }:
{
  # --------------------------------------------------------------------- polkit
  # Privilege escalation framework, plus the pkexec setuid wrapper so GUI apps can
  # request Polkit authentication.
  security.polkit.enable = true;

  security.wrappers.pkexec = {
    source = "${pkgs.polkit}/bin/pkexec";
    owner = "root";
    group = "root";
    setuid = true;
  };

  # Power actions without a password prompt.
  #
  # This session is greetd -> niri.service, i.e. niri runs as a systemd *user service*, so
  # niri and every process it spawns live under user@1000.service rather than in a logind
  # session scope. logind therefore cannot associate those processes with a session
  # (GetSessionByPID answers "does not belong to any known session"), polkit cannot attach
  # an authentication agent to them, and every action whose policy is auth_admin_keep -
  # suspend, reboot, power-off - fails with:
  #
  #   "Access denied as the requested operation requires interactive authentication.
  #    However, interactive authentication has not been enabled by the calling program."
  #
  # That is what made the quickshell power menu do nothing for suspend / restart /
  # shutdown (lock and logout are unaffected: they never go through polkit), and it would
  # also have stopped swayidle's "timeout 14400 'systemctl suspend'".
  #
  # Granting those actions to "wheel" up front is the documented approach for a compositor
  # that is not a full desktop environment. Only the six login1 power actions are touched;
  # everything else keeps the default policy. The two destructive ones are additionally
  # guarded by an explicit confirmation step in the power menu itself.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.login1.") !== 0
          || !subject.isInGroup("wheel")) {
        return polkit.Result.NOT_HANDLED;
      }

      var allowed = [
        "org.freedesktop.login1.suspend",
        "org.freedesktop.login1.suspend-multiple-sessions",
        "org.freedesktop.login1.hibernate",
        "org.freedesktop.login1.hibernate-multiple-sessions",
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions",
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions"
      ];

      return allowed.indexOf(action.id) === -1
        ? polkit.Result.NOT_HANDLED
        : polkit.Result.YES;
    });
  '';
}
