{ config, pkgs, ... }:

let
  # nixpkgs builds nvibrant against NVIDIA's open-gpu headers only up to driver
  # 610.43.02, but the 615 branch (see the package comment below) changed the NVAPI
  # struct layout, so every ioctl fails ("AllocDevice ioctl failed") and nvibrant
  # exits 1 - which kills the cs2 launcher before Steam ever starts. Rebuild it
  # against the driver that is actually running. openGpuHash has to be refreshed
  # when the driver moves to a version with no matching open-gpu tag yet.
  driverVersion = config.hardware.nvidia.package.version;
  openGpuHash = "sha256-A8EDw5nKg66VNwczEnUSwFvosB6puhvJjgdaGpSJMvA=";
in

{
  nixpkgs.overlays = [
    (final: prev: {
      nvibrant = prev.nvibrant.overrideAttrs (old: {
        version = "${old.passthru.nvibrantVersion}-unstable-${driverVersion}";

        srcs = [
          old.passthru.srcAttrs.nvibrant
          (old.passthru.srcAttrs.open-gpu.overrideAttrs (_: { hash = openGpuHash; }))
        ];

        # The unpack script generates a header patch per open-gpu tag and stops at
        # latestDriverVersion; point that stop at the driver in use.
        postUnpack = builtins.replaceStrings
          [ old.passthru.latestDriverVersion ]
          [ driverVersion ]
          old.postUnpack;
      });
    })
  ];

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
