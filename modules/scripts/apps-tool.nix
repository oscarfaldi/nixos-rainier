{ config, pkgs, ... }:

let

  mkScript = name:
    pkgs.writeShellScriptBin name
      (builtins.readFile ../../modules/scripts/apps/${name});

in
{

  # ============================================================
  # Application Scripts
  # ============================================================

  environment.systemPackages = [
    (mkScript "cs2")
    (mkScript "davinci")
    (mkScript "btop-launch")
    (mkScript "yazi-launch")
    (mkScript "zapzap-backup")
  ];
}
