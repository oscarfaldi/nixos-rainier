{ config, lib, pkgs, ... }:

{
  # ============================================================
  # Themes
  #
  # The official palettes ship read-only from the repo. Switching between them does NOT need a
  # rebuild: colours, wallpaper and the rendered app configs all live in $XDG_STATE_HOME/theme/,
  # written by modules/scripts/themes/theme-apply. Nix only carries the pointers each app reads.
  #
  # User themes (tweaks, community drops) go in ~/.local/share/qs-palettes-user/ and shadow an official
  # theme of the same name; theme-apply creates that directory on first use.
  # ============================================================

  # The official palettes are published system-wide as /etc/qs-palettes
  # (see modules/scripts/themes-tool.nix) instead of a home.file entry. /etc is a read-only link into
  # the store, so a stray directory in $HOME can never collide with it and abort activation.

  # ============================================================
  # GTK: owned by theme-apply, not by Home Manager
  #
  # theme-apply owns ~/.config/gtk-3.0/settings.ini, so a theme switch changes the GTK theme without
  # a rebuild.
  # The packages still come from Nix because they must exist on disk.
  #
  # Why real themes and not one Adwaita recoloured by CSS: GTK 3.24's Adwaita has literal hex values
  # in its rules (it defines @theme_bg_color but never uses it), so @define-color overrides do
  # nothing. A palette therefore names an installed theme through `gtk_theme` in its colors.toml.
  # ============================================================

  home.packages = with pkgs; [
    papirus-icon-theme
    bibata-cursors
    # Adwaita-dark ships here, and it is the fallback GTK theme for palettes without one of their
    # own. Dropping programs.gtk removed it and every fallback landed on the LIGHT
    # builtin Adwaita instead - keep this package installed.
    gnome-themes-extra
    # gruvbox has no native GTK port worth keeping, so its palette generates one from Nordic
    # instead (see generate_gtk in themes/gruvbox/colors.toml). Nordic is the only base theme that
    # has to be installed for that to work.
    nordic
  ];


  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
