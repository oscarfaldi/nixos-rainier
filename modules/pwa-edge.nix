{ config, pkgs, lib, ... }:

let
  mkPWA = { name, url, icon }:
    pkgs.makeDesktopItem {
      # Internal desktop entry name
      name = lib.strings.toLower name;

      # Displayed app name
      desktopName = name;

      # Open as Edge app window
      exec = "microsoft-edge --app=${url}";

      icon = icon;

      categories = [ "Network" ];
    };

  # Internal services are addressed by their hostname (server.local, movies.local, ...)
  # instead of 10.10.10.10:PORT. Chromium keys per-site zoom by HOST only, so one
  # hostname per service is what makes a separate zoom level per app possible; the
  # names resolve through /etc/hosts.

in
{
  # Native Wayland support for Edge and Electron apps
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [

    (mkPWA {
      name = "ChatGPT";
      url = "https://chatgpt.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/chatgpt.svg";
    })

    (mkPWA {
      name = "Open WebUI";
      url = "http://ai.local:8072/";
      icon = "${config.my.repoPath}/assets/icons/pwa/openwebui.svg";
    })

    (mkPWA {
      name = "Gemini";
      url = "https://gemini.google.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/gemini.svg";
    })

    (mkPWA {
      name = "Claude";
      url = "https://claude.ai";
      icon = "${config.my.repoPath}/assets/icons/pwa/claude.svg";
    })

    (mkPWA {
      name = "Unraid";
      url = "http://server.local:8081/";
      icon = "${config.my.repoPath}/assets/icons/pwa/unraid.svg";
    })

    (mkPWA {
      name = "WhatsApp";
      url = "https://web.whatsapp.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/whatsapp.svg";
    })

    (mkPWA {
      name = "Wordpress";
      url = "https://oscarfaldi.com/wp-admin";
      icon = "${config.my.repoPath}/assets/icons/pwa/wordpress.svg";
    })

    (mkPWA {
      name = "Jellyfin";
      url = "http://movies.local:8096/";
      icon = "${config.my.repoPath}/assets/icons/pwa/jellyfin.svg";
    })

    (mkPWA {
      name = "Navidrome";
      url = "http://music.local:4533/";
      icon = "${config.my.repoPath}/assets/icons/pwa/navidrome.svg";
    })

    (mkPWA {
      name = "Krusader";
      url = "https://krusader.local:8242/";
      icon = "${config.my.repoPath}/assets/icons/pwa/krusader.svg";
    })

    (mkPWA {
      name = "Grafana";
      url = "http://grafana.local:3050/d/rYdddlPWk/node-exporter-full/";
      icon = "${config.my.repoPath}/assets/icons/pwa/grafana.svg";
    })

    (mkPWA {
      name = "qBittorrent";
      url = "http://torrent.local:8080/";
      icon = "${config.my.repoPath}/assets/icons/pwa/qbittorrent.svg";
    })

    (mkPWA {
      name = "Gmail";
      url = "https://mail.google.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/gmail.svg";
    })

    (mkPWA {
      name = "Google Sheets";
      url = "https://docs.google.com/spreadsheets/";
      icon = "${config.my.repoPath}/assets/icons/pwa/sheets.svg";
    })

    (mkPWA {
      name = "Hermes Agent";
      url = "http://hermes.local:9119/";
      icon = "${config.my.repoPath}/assets/icons/pwa/hermes.svg";
    })
  ];
}
