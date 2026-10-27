{ config, pkgs, ... }:

{
  # Keyboard remapping daemon
  services.keyd = {
    enable = true;

    keyboards = {
      default = {
        ids = [ "*" ];

        settings = {
          main = {
            # Force proper Function Keys
            brightnessdown = "f1";
            brightnessup   = "f2";

            scale          = "f3";
            dashboard      = "f4";

            kbdillumdown   = "f5";
            kbdillumup     = "f6";

            previoussong   = "f7";
            playpause      = "f8";
            nextsong       = "f9";

            mute           = "f10";
            volumedown     = "f11";
            volumeup       = "f12";
          };
        };
      };
    };
  };
}
