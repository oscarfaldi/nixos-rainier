{ config, pkgs, ... }:

let

  mkScript = name:
    pkgs.writeShellScriptBin name
      (builtins.readFile ../../modules/scripts/launchers/${name});

in
{

  # ============================================================
  # Environment Scripts (Launchable Tools)
  # ============================================================

  environment.systemPackages = [
    (mkScript "config-menu")
    (mkScript "configuration-menu")
    (mkScript "modules-menu")
    (mkScript "power-menu")
    (mkScript "system-menu")
    (mkScript "nas-menu")
  ];
}
