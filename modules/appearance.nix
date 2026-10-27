{ config, pkgs, ... }:

{
  # ============================================================
  # Fonts
  # ============================================================

  fonts = {
    packages = with pkgs; [

      # ----------------------------------------------------------
      # Nerd Fonts
      # ----------------------------------------------------------

      nerd-fonts.iosevka-term-slab
      nerd-fonts.jetbrains-mono

      # ----------------------------------------------------------
      # Monospace
      # ----------------------------------------------------------

      jetbrains-mono
      ibm-plex

      # ----------------------------------------------------------
      # UI Fonts
      # ----------------------------------------------------------

      inter

      # ----------------------------------------------------------
      # Microsoft Standard Fonts
      # ----------------------------------------------------------

      corefonts # Arial, Times New Roman, Courier New, Verdana
      vista-fonts # Calibri, Cambria, Consolas, Segoe UI
      liberation_ttf # Open-source exact metric fallbacks for MS Fonts

      # ----------------------------------------------------------
      # Unicode Coverage
      # ----------------------------------------------------------

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    fontconfig = {
      enable = true;

      defaultFonts = {
        monospace = [
          "IosevkaTermSlab Nerd Font"
          "JetBrains Mono"
          "BlexMono Nerd Font"
          "Consolas"
          "Liberation Mono"
        ];

        sansSerif = [
          "IBM Plex Sans"
          "Noto Sans"
          "Inter"
          "Arial"
          "Calibri"
          "Liberation Sans"
        ];

        serif = [
          "IBM Plex Serif"
          "Noto Serif"
          "Liberation Serif"
          "Times New Roman"
          "Cambria"
        ];

        emoji = [
          "Noto Color Emoji"
        ];
      };
    };
  };
}
