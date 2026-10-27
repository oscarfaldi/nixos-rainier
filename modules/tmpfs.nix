{ config, pkgs, ... }:

{
  # --------------------------------------------------
  # RAM-backed Temporary Filesystem
  # --------------------------------------------------

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";

    options = [
      "size=8G"
      "mode=1777"
    ];
  };
}
