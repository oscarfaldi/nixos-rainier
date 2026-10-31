{ config, lib, pkgs, ... }:

# FilmCraft (ArtCraft) — open-source, native video editor (Premiere/Resolve-shaped UI).
# Not in nixpkgs at any revision yet, so it is packaged from the official AppImage.
#
# Declarative here:
#   - the app itself (AppImage wrapper below)
#   - two seed files in assets/filmcraft/: the "Premiere Pro Compatible" shortcut set and a
#     preferences.json pinning the English UI and an empty project at startup. They are copied
#     into ~/.local/share/filmcraft only when the live file is missing, so the app keeps
#     ownership of them afterwards (a store symlink would break its own saves).
# Everything else the app writes — window layout, recent projects, autosave, cache — is
# runtime state and is deliberately not managed here.
#
# Bump: change `version`, then re-run
#   nix store prefetch-file --json --name f.AppImage <the release URL below>
# and paste the new `hash`.
#
# Removal: delete this file, delete its line in the configuration.nix imports list, and delete
# assets/filmcraft/. Live settings under ~/.local/share/filmcraft stay behind by design.

let
  version = "0.15.0";

  src = pkgs.fetchurl {
    url = "https://github.com/storytold/filmcraft/releases/download/v${version}/filmcraft-${version}-linux-x86_64.AppImage";
    hash = "sha256-S8sRnBqmDfVM4zONeqSOPxTWFWn3vGOFGgC9yJJJZHs=";
  };

  contents = pkgs.appimageTools.extract {
    pname = "filmcraft";
    inherit version src;
  };

  seed = ../assets/filmcraft;

  # .fcpxml is not a registered type (it falls back to application/xml, which opens Edge),
  # so double-clicking a rough cut did nothing useful. Ship a mime type for that extension
  # and a hidden handler entry, then make it the default below.
  fcpxmlMime = pkgs.runCommandLocal "filmcraft-fcpxml-mime" { } ''
    mkdir -p $out/share/mime/packages $out/share/applications

    cat > $out/share/mime/packages/x-fcpxml.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-fcpxml">
    <comment>Final Cut Pro XML timeline</comment>
    <glob pattern="*.fcpxml"/>
  </mime-type>
</mime-info>
XML

    cat > $out/share/applications/filmcraft-fcpxml.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=FilmCraft Timeline
Exec=filmcraft %f
MimeType=application/x-fcpxml;
NoDisplay=true
Terminal=false
StartupNotify=false
DESKTOP
  '';
in

{
  # Double-clicking a .fcpxml timeline opens it in FilmCraft.
  xdg.mime.defaultApplications."application/x-fcpxml" = "filmcraft-fcpxml.desktop";

  environment.systemPackages = [
    fcpxmlMime

    (pkgs.appimageTools.wrapType2 {
      pname = "filmcraft";
      inherit version src;

      extraInstallCommands = ''
        mkdir -p $out/share
        install -Dm444 ${contents}/usr/share/applications/ai.storyteller.filmcraft.desktop \
          $out/share/applications/ai.storyteller.filmcraft.desktop
        cp -r ${contents}/usr/share/icons $out/share/
      '';
    })
  ];

  # Seed only when absent: FilmCraft rewrites both files itself, so they must stay real files
  # in the data dir, never symlinks into the read-only store.
  home-manager.users.${config.my.username} = { lib, ... }: {
    home.activation.filmcraftSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      filmcraftData="$HOME/.local/share/filmcraft"
      run mkdir -p "$filmcraftData/Keyboard Shortcuts"

      if [ ! -e "$filmcraftData/preferences.json" ]; then
        run ${pkgs.coreutils}/bin/install -Dm644 ${seed}/preferences.json "$filmcraftData/preferences.json"
      fi

      if [ ! -e "$filmcraftData/Keyboard Shortcuts/active.json" ]; then
        run ${pkgs.coreutils}/bin/install -Dm644 ${seed}/active.json "$filmcraftData/Keyboard Shortcuts/active.json"
      fi
    '';
  };
}
