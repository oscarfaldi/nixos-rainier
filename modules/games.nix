# ============================================================
# Steam & Gaming
# ============================================================
#
# Purpose:
# - Steam client, and the Proton runtimes every game runs on
# - Gamescope support for Wayland/Niri
# - Gamemode performance optimizations
# - Per-game prefix maintenance
#
# Why Steam carries Proton: a bare Proton build cannot run here. NixOS has no
# /lib64/ld-linux, so Proton only works inside the FHS sandbox Steam builds for
# it. Steam is not acting as a store in that role either - a non-Steam shortcut
# only borrows the engine, so a cracked .exe stays a cracked .exe.
#
# ============================================================

{ pkgs, ... }:

{
  # --------------------------------------------------
  # Steam client
  # --------------------------------------------------
  programs.steam = {
    enable = true;

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;

    # Upstream Proton plus the fixes Valve has not merged yet (media foundation
    # codecs for cutscenes, launcher workarounds). Non-Steam releases are the
    # case that needs them, and declaring the build here means it survives a
    # reinstall instead of being downloaded by hand into the Steam directory.
    # Steam lists it as "GE-Proton11-7".
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # --------------------------------------------------
  # Wayland session helpers
  # --------------------------------------------------
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;

  # --------------------------------------------------
  # Prefix maintenance
  # --------------------------------------------------
  # One prefix per game lives under steamapps/compatdata. protontricks runs
  # installers and winetricks verbs inside that prefix, so a second Wine
  # environment never has to be maintained next to Proton.
  #
  #   protontricks <appid>                        verb menu for one game
  #   protontricks <appid> -c 'wine setup.exe'    run a binary in that prefix
  environment.systemPackages = [
    pkgs.protontricks
  ];
}
