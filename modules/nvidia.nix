{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    open = false;

    modesetting.enable = true;

    powerManagement.enable = true;

    nvidiaSettings = true;

    # New feature branch (615.x) instead of production (595.x): on 595 the driver
    # exhausts BAR1 mapping space after long uptimes, then fails the atomic modeset
    # and freezes the desktop (NVIDIA/open-gpu-kernel-modules #1132, #1411, #1449).
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
