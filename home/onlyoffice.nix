{ config, pkgs, lib, ... }:

let
  onlyofficeFonts = with pkgs; [
    # ==========================================================
    # Nerd Fonts
    # ==========================================================

    nerd-fonts.iosevka-term-slab
    nerd-fonts.jetbrains-mono

    # ==========================================================
    # Monospace
    # ==========================================================

    jetbrains-mono
    ibm-plex

    # ==========================================================
    # UI Fonts
    # ==========================================================

    inter

    # ==========================================================
    # Microsoft Fonts
    # ==========================================================

    corefonts
    vista-fonts
    liberation_ttf

    # ==========================================================
    # Unicode Coverage
    # ==========================================================

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];
in
{
  # ============================================================
  # ONLYOFFICE Font Workaround
  # ============================================================

  home.activation.onlyoffice-fonts =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      FONT_DIR="$HOME/.local/share/fonts/onlyoffice"

      rm -rf "$FONT_DIR"
      mkdir -p "$FONT_DIR"

      copy_fonts() {
        if [ -d "$1/share/fonts" ]; then
          find "$1/share/fonts" \
            -type f \
            \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \) \
            -exec cp -f {} "$FONT_DIR/" \;
        fi
      }

      ${lib.concatMapStringsSep "\n" (pkg: ''
        copy_fonts "${pkg}"
      '') onlyofficeFonts}

      ${pkgs.fontconfig}/bin/fc-cache -fv "$FONT_DIR"

      rm -rf \
        "$HOME/.local/share/onlyoffice/desktopeditors/data/fonts"
    '';

  # ============================================================
  # ONLYOFFICE Notes
  # ============================================================

  xdg.configFile."onlyoffice/README".text = ''
    Preferred Configuration

    Theme
    -----
    • Dark

    Default Font
    ------------
    • Arial

    Spreadsheet
    -----------
    • Font Size: 11

    Auto Recovery
    -------------
    • Enabled
    • Every 1 minute

    Number Format
    -------------
    • Decimal Separator: .
    • Thousands Separator: ,

    Date Format
    -----------
    • DD/MM/YYYY
  '';
}
