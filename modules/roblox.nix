{ config, pkgs, lib, ... }:

# Roblox Player on Linux.
#
# Roblox ships no Linux client, and the compatibility layer that runs it (Sober, from
# VinegarHQ) is only distributed as a Flathub package, so Flatpak is the only route.
# Roblox Studio is a different product and is available natively as pkgs.vinegar.
#
# How it works: a oneshot unit adds the Flathub remote, installs org.vinegarhq.Sober once
# and then keeps it updated (see updateSober below). Flatpak ships its own .desktop file,
# so the app appears in the launcher by itself. The unit re-runs on every boot but skips
# the install once Sober is present, which makes a manual uninstall heal on the next reboot.
#
# Removal:
#   1. delete this file and its line in the configuration.nix imports list
#   2. rebuild, then: sudo flatpak uninstall --system --all && sudo rm -rf /var/lib/flatpak
#
# The first launch downloads the Roblox client itself into the sandbox.

let
  flatpak = "${pkgs.flatpak}/bin/flatpak";

  # Flathub ships REFRESHED Sober builds that keep the same version number: 1.8.0 was
  # refreshed with a newer Roblox client tag, and Sober then refuses to start once Roblox
  # requires that client - the message is "Sober is outdated". An install-once unit rots
  # exactly that way, because nothing ever tells Flatpak to look again. Updating is
  # Flatpak's own release channel, so the flake is not involved and no version is pinned
  # here on purpose.
  updateSober = pkgs.writeShellScript "flatpak-update-sober" ''
    set -eu

    ${flatpak} remote-add --system --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo

    ${flatpak} update --system --noninteractive -y org.vinegarhq.Sober || \
      echo "Sober update skipped (offline, or nothing to update)."
  '';

  installSober = pkgs.writeShellScript "flatpak-install-sober" ''
    set -eu

    ${flatpak} remote-add --system --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo

    if ${flatpak} info --system org.vinegarhq.Sober >/dev/null 2>&1; then
      echo "Sober is already installed."
    else
      ${flatpak} install --system --noninteractive -y flathub org.vinegarhq.Sober
    fi

    ${updateSober}
  '';
in

{
  services.flatpak.enable = true;

  # Sober lands in /var/lib/flatpak/exports/share/applications, and Quickshell only
  # starts watching desktop-entry directories that already exist when the shell comes
  # up (DesktopEntryMonitor::startMonitoring skips missing paths). On a fresh install
  # the directory does not exist until the download above finishes, which is minutes
  # after the shell is already running, so Roblox never reached the launcher until the
  # next login. Creating the directory at boot means it is watched before the install
  # writes into it, and the launcher picks the entry up live.
  systemd.tmpfiles.rules = [
    "d /var/lib/flatpak/exports/share/applications 0755 root root -"
  ];

  systemd.services.flatpak-install-sober = {
    description = "Install Roblox (Sober) from Flathub";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # the first install pulls ~1.5 GB, never let the default 90s timeout kill it
      TimeoutStartSec = "infinity";
      ExecStart = installSober;
    };
  };

  # A boot-only update is not enough: this machine stays up for days, so the app goes
  # stale while it is running. Daily, Persistent so a missed run happens at the next
  # boot, plus a delay so it does not race the network at login.
  systemd.services.flatpak-update-sober = {
    description = "Update Roblox (Sober) from Flathub";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
      ExecStart = updateSober;
    };
  };

  systemd.timers.flatpak-update-sober = {
    description = "Daily Roblox (Sober) update from Flathub";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
