{ pkgs, ... }:

{
  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
      NewTabPage = false;

      FirefoxHome = {
        SponsoredTopSites = false;
        SponsoredPocket = false;
      };

      # Search engine suggestions, not Firefox Suggest
      SearchSuggestEnabled = true;

      # Skip first-run / onboarding / "safe paws" welcome screen sepenuhnya
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      UserMessaging = {
        WhatsNew = false;
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        MoreFromMozilla = false;
        SkipOnboarding = true;
        Locked = true;
      };

      # Declarative extension installation directly from Mozilla Add-ons (AMO)
      Extensions = {
        Install = [
          "https://addons.mozilla.org/firefox/downloads/latest/twitter-file-downloader/latest.xpi"
          "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi"
          "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
          "https://addons.mozilla.org/firefox/downloads/latest/ins-downloader/latest.xpi"
        ];
      };

      Preferences = {
        "browser.ml.enable" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.enabled" = {
          Value = false;
          Status = "locked";
        };
      };
    };

    profiles.default = {
      settings = {
        "toolkit.telemetry.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "app.shield.optoutstudies.enabled" = false;

        "browser.search.suggest.enabled" = true;
        "browser.urlbar.suggest.searches" = true;
        "browser.urlbar.suggest.quicksuggest" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;

        "browser.startup.page" = 3;
        "general.smoothScroll" = false;

        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;

        "signon.rememberSignons" = false;

        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        "network.trr.mode" = 3;
        "network.trr.uri" = "https://cloudflare-dns.com/dns-query";

        "widget.gtk.rounded-bottom-corners.enabled" = true;

        "browser.tabs.closeWindowWithLastTab" = false;
        "browser.tabs.firefox-view" = false;

        "browser.download.useDownloadDir" = true;

        "extensions.pocket.enabled" = false;
        "browser.shopping.experience2023.enabled" = false;
        "reader.parse-on-load.enabled" = false;
      };
    };
  };
}
