{ config, lib, ... }:

let
  # nixpkgs only generates nvibrant's open-gpu header patches up to the tag stored
  # in nvibrant.passthru.latestDriverVersion (610.43.02 in this pin). The 615
  # branch changed the NVAPI struct layout, so a binary built against the 610
  # headers fails every ioctl ("AllocDevice ioctl failed") and exits 1 - which
  # kills the cs2 launcher before Steam ever starts. Walk the tag chain up to the
  # driver that is actually running instead.
  driverVersion = config.hardware.nvidia.package.version;
  nvibrantPatchEnd = "610.43.02";

  # Hash of nvidia/open-gpu-kernel-modules@515.43.04 with the patch series
  # regenerated through the running driver version. When the driver moves past a
  # version this nixpkgs pin already patches, set this to lib.fakeHash, build
  # once, and copy the "got:" hash out of the fixed-output hash mismatch error.
  openGpuHash = "sha256-A8EDw5nKg66VNwczEnUSwFvosB6puhvJjgdaGpSJMvA=";
in
{
  nixpkgs.overlays = [
    (final: prev: {
      nvibrant = prev.nvibrant.overrideAttrs (old: {
        version = "${old.passthru.nvibrantVersion}-unstable-${driverVersion}";

        srcs = [
          old.passthru.srcAttrs.nvibrant
          (old.passthru.srcAttrs.open-gpu.overrideAttrs (openGpu: {
            # The tag walk lives in postCheckout, and the stop tag is already
            # interpolated into that script, so rewrite it there. postUnpack only
            # moves directories and never contains a driver version.
            postCheckout = builtins.replaceStrings
              [ nvibrantPatchEnd ]
              [ driverVersion ]
              openGpu.postCheckout;

            hash = openGpuHash;
          }))
        ];
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
