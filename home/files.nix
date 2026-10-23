# ==============================================================================
# Home Manager File Declarations
# ==============================================================================
# This module declaratively links user configuration files and directories from
# the local dotfiles repository into the user's home directory.
#
# Sections:
# - Core Shell & Terminal Environment
# - System Interface & Wayland Compositor (Niri)
# - Applications, Viewers & Media Tools
# - Desktop Automation, Security & Utilities
# ==============================================================================

{ config, lib, ... }:

let
  # Applications that should stay out of every launcher. The list lives in one text file next to
  # the shell, and each line becomes a tombstone .desktop file below, so the usual XDG hiding
  # (GIO, ...) agrees with what the shell's launcher shows. Nix is the generator only:
  # the file is the single source of truth.
  hiddenApplications =
    builtins.filter
      (line: line != "" && builtins.substring 0 1 line != "#")
      (lib.splitString "\n"
        (builtins.readFile ../.config/quickshell/main/launcher.hides));

  # One symlink per file instead of one for the whole directory: a directory symlink cannot be
  # extended with generated files, and home-manager refuses to write inside it.
  applicationLinks = lib.listToAttrs (map
    (name: {
      name = ".local/share/applications/${name}";
      value.source = ../.local/share/applications/${name};
    })
    (builtins.attrNames (builtins.readDir ../.local/share/applications)));

  tombstoneLinks = lib.listToAttrs (map
    (id: {
      name = ".local/share/applications/${id}";
      value.text = ''
        [Desktop Entry]
        Type=Application
        Hidden=true
      '';
    })
    hiddenApplications);
in
{
  home.file = {

    # --------------------------------------------------------------------------
    # Core Shell & Terminal Environment
    # --------------------------------------------------------------------------
    ".config/aliasrc".source   = ../.config/aliasrc;
    ".config/fastfetch".source = ../.config/fastfetch;

    # Ghostty Assets
    ".config/ghostty/shaders".source =
      ../.config/ghostty/shaders;

    # --------------------------------------------------------------------------
    # System Interface & Wayland Compositor (Niri)
    # --------------------------------------------------------------------------
    ".config/niri".source    = ../.config/niri;

    # --------------------------------------------------------------------------
    # Applications, Viewers & Media Tools
    # --------------------------------------------------------------------------
    ".config/yazi".source                   = ../.config/yazi;
    ".config/mpv".source                    = ../.config/mpv;
    ".config/qimgv".source                  = ../.config/qimgv;
    ".config/pdfarranger".source            = ../.config/pdfarranger;
    ".config/obsidian/obsidian.json".source = ../.config/obsidian/obsidian.json;

    # --------------------------------------------------------------------------
    # Desktop Automation, Security & Utilities
    # --------------------------------------------------------------------------
    # so it must not be mapped here: two writers would fight over the same path.
    ".config/Thunar".source            = ../.config/Thunar;
    ".config/gtk-3.0/bookmarks".source = ../.config/gtk-3.0/bookmarks;
    ".config/mimeapps.list".source     = ../.config/mimeapps.list;

    # --------------------------------------------------------------------------
    # System Integration
    # --------------------------------------------------------------------------
    ".config/xdg-desktop-portal".source =
      ../.config/xdg-desktop-portal;

    # declared per file at the end of this file, together with the generated tombstones
  } // applicationLinks // tombstoneLinks;
}