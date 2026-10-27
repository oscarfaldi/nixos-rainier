{ config, pkgs, ... }:

{
  programs.microsoft-edge = {
    enable = true;

    extensions = [
      { id = "inomeogfingihgjfjlpeplalcfajhgai"; } # Chrome Remote Desktop
      { id = "bgnkhhnnamicmpeenaelnjfhikgbkllg"; } # AdGuard AdBlocker
      { id = "jlhgedjpndhblehblebhncfmkkpngiep"; } # Reddit Enhancement Suite
      { id = "cpgaheeihidjmolbakklolchdplenjai"; } # Turbo Downloader for Instagram
      { id = "piibekljdlkbkdchicfdjpnaggolndif"; } # Plucker XBD - X (Twitter) Media One-click Downloader
      { id = "dbepbhhcmhodojepbagfppgpieeplpik"; } # FetchV - Video Downloader for M3U8 & HLS
      { id = "fclobfmgolhdcfcmpbjahiiifilhamcg"; } # Easy TikTok Video Downloader (Remove Watermark)
      { id = "cclelndahbckbenkjhflpdbgdldlbecc"; } # Get cookies.txt Locally

      # Legacy Chromium
      # { id = "ldgfbffkinooeloadekpmfoklnobpien"; } # Raindrop.io
      # { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
    ];

    commandLineArgs = [
      # UI
      "--disable-smooth-scrolling"
      "--disable-features=TabHoverCardImages"

      # Wayland
      "--ozone-platform=wayland"
    ];
  };
}
