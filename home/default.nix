{ config, osConfig, pkgs, ... }:

{
  imports = [
    ./files.nix
    ./shell.nix
    ./xdg.nix
    ./edge.nix
    ./ghostty.nix
    ./thunar.nix
    ./themes.nix
    ./quickshell.nix
    ./starship.nix
    ./ssh.nix
    ./git.nix
  ];

  home.username = osConfig.my.username;
  home.homeDirectory = osConfig.my.home;

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
