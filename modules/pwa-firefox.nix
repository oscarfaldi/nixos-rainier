{ config, pkgs, lib, ... }:

let
  mkWebApp = { name, url, icon }:
    pkgs.makeDesktopItem {
      # Internal desktop entry name
      name = lib.strings.toLower name;

      # Displayed app name
      desktopName = name;

      # Launch URL in Firefox
      exec = "firefox --new-window ${url}";

      icon = icon;

      categories = [ "Network" ];
    };

in
{
  environment.systemPackages = with pkgs; [

    (mkWebApp {
      name = "ChatGPT";
      url = "https://chatgpt.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/chatgpt.svg";
    })

    (mkWebApp {
      name = "Open WebUI";
      url = "http://10.10.10.10:8072/";
      icon = "${config.my.repoPath}/assets/icons/pwa/openwebui.svg";
    })

    (mkWebApp {
      name = "Gemini";
      url = "https://gemini.google.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/gemini.svg";
    })

    (mkWebApp {
      name = "Claude";
      url = "https://claude.ai";
      icon = "${config.my.repoPath}/assets/icons/pwa/claude.svg";
    })

    (mkWebApp {
      name = "Unraid";
      url = "http://10.10.10.10:8081/";
      icon = "${config.my.repoPath}/assets/icons/pwa/unraid.svg";
    })

    (mkWebApp {
      name = "WhatsApp";
      url = "https://web.whatsapp.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/whatsapp.svg";
    })

    (mkWebApp {
      name = "Wordpress";
      url = "https://oscarfaldi.com/wp-admin";
      icon = "${config.my.repoPath}/assets/icons/pwa/wordpress.svg";
    })

    (mkWebApp {
      name = "Jellyfin";
      url = "http://10.10.10.10:8096/";
      icon = "${config.my.repoPath}/assets/icons/pwa/jellyfin.svg";
    })

    (mkWebApp {
      name = "Navidrome";
      url = "http://10.10.10.10:4533/";
      icon = "${config.my.repoPath}/assets/icons/pwa/navidrome.svg";
    })

    (mkWebApp {
      name = "Krusader";
      url = "https://10.10.10.10:8242/";
      icon = "${config.my.repoPath}/assets/icons/pwa/krusader.svg";
    })

    (mkWebApp {
      name = "Grafana";
      url = "http://10.10.10.10:3050/d/rYdddlPWk/node-exporter-full/";
      icon = "${config.my.repoPath}/assets/icons/pwa/grafana.svg";
    })

    (mkWebApp {
      name = "Gmail";
      url = "https://mail.google.com";
      icon = "${config.my.repoPath}/assets/icons/pwa/gmail.svg";
    })
  ];
}
