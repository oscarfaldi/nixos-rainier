{ config, pkgs, lib, ... }:

# Roblox Player on Linux.
#
# Roblox ships no Linux client, and the compatibility layer that runs it (Sober, from
# VinegarHQ) is only distributed as a Flathub package, so Flatpak is the only route.
# Roblox Studio is a different product and is available natively as pkgs.vinegar.
#
# How it works: a oneshot unit adds the Flathub remote and installs
# org.vinegarhq.Sober once. Flatpak ships its own .desktop file, so the app appears in
# the launcher by itself. The unit re-runs on every boot but exits immediately once
# Sober is installed, which makes a manual uninstall heal on the next reboot.
#
# Removal:
#   1. delete this file and its line in the configuration.nix imports list
#   2. rebuild, then: sudo flatpak uninstall --system --all && sudo rm -rf /var/lib/flatpak
#
# The first launch downloads the Roblox client itself into the sandbox.

let
  flatpak = "${pkgs.flatpak}/bin/flatpak";

  installSober = pkgs.writeShellScript "flatpak-install-sober" ''
    set -eu

    ${flatpak} remote-add --system --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo

    if ${flatpak} info --system org.vinegarhq.Sober >/dev/null 2>&1; then
      echo "Sober is already installed."
      exit 0
    fi

    ${flatpak} install --system --noninteractive -y flathub org.vinegarhq.Sober
  '';
in

{
  services.flatpak.enable = true;

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
}
