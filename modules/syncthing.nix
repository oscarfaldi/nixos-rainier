{ config, pkgs, ... }:

{
  services.syncthing = {
    enable = true;

    user = config.my.username;

    dataDir = config.my.home;
    configDir = "${config.my.home}/.config/syncthing";

    openDefaultPorts = true;

    settings = {
      devices = {
        cascade = {
          id = "CW6KEXA-LJKBC6W-KYYKRJZ-BGAEUPZ-OHONXDF-VPIBUEC-RFSZLMY-74EGFQC";
        };
      };

      folders = {
        "qvuul-fxrvu" = {
          id = "qvuul-fxrvu";

          path = "${config.my.home}/Obsidian Vault";

          devices = [ "cascade" ];

          type = "sendreceive";

          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
        };
      };

      options = {
        urAccepted = -1;
      };
    };
  };
}
