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

    package =
      config.boot.kernelPackages.nvidiaPackages.production;
  };
}
