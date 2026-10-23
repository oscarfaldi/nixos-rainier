# ============================================================
# Steam & Gaming
# ============================================================
#
# Purpose:
# - Steam gaming platform
# - Gamescope support for Wayland/Niri
# - Gamemode performance optimizations
# - Proton-GE management utility
#
# ============================================================

{ pkgs, ... }:

{
  programs.steam = {
    enable = true;

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    protonup-qt
  ];
}
