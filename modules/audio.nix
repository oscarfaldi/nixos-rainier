{ config, pkgs, ... }:

{
  # --------------------------------------------------
  # PipeWire Audio and Low-Latency Scheduling
  # --------------------------------------------------

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    # ALSA Support
    alsa.enable = true;
    alsa.support32Bit = true;

    # PulseAudio Compatibility Layer
    pulse.enable = true;

    # Session and Device Manager
    wireplumber.enable = true;
  };

  # Device and profile picker. WirePlumber decides the default output; when it picks the wrong one,
  # this is where it gets changed - no scripts, no stored preference to go stale.
  environment.systemPackages = [ pkgs.pwvucontrol ];
}
