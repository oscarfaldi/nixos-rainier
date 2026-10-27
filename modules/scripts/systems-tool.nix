{ config, pkgs, ... }:

let

  mkScript = name:
    pkgs.writeShellScriptBin name
      (builtins.readFile ../../modules/scripts/systems/${name});

in
{

  # ============================================================
  # Environment Scripts (System Maintenance & Utilities)
  # ============================================================

  environment.systemPackages = [
    (mkScript "clean")
    (mkScript "rebuild")
    (mkScript "rebuild-boot")
    (mkScript "upgrade")
    (mkScript "version")
    (mkScript "niri-session-safe")
    (mkScript "qs-check")
    (mkScript "smart-report")
    (mkScript "nas-recover")
  ];
}
