{ pkgs, ... }:

# PhotoCraft (ArtCraft) — open-source, native image editor with layered PSD support,
# the Photoshop replacement he has no other stand-in for.
#
# Packaged from the official AppImage because the nixpkgs attribute (`photocraft`,
# available since ~0.16.0) is newer than the pinned nixpkgs revision. After a
# `nix flake update` this file collapses to `environment.systemPackages = [ pkgs.photocraft ];`.
#
# Bump: change `version`, then re-run
#   nix store prefetch-file --json --name p.AppImage <the release URL below>
# and paste the new `hash`.
#
# Removal: delete this file and its line in the configuration.nix imports list.
#
# The app ships its own .desktop entry and icons; they are copied out of the AppImage
# so it shows up in the launcher.

let
  version = "0.18.0";

  src = pkgs.fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${version}/photocraft-${version}-linux-x86_64.AppImage";
    hash = "sha256-gwdXrK6Htd6iDyUgA5LeEYoUOjXcG1IEGjUmEgJn5oQ=";
  };

  contents = pkgs.appimageTools.extract {
    pname = "photocraft";
    inherit version src;
  };
in

{
  environment.systemPackages = [
    (pkgs.appimageTools.wrapType2 {
      pname = "photocraft";
      inherit version src;

      extraInstallCommands = ''
        mkdir -p $out/share
        install -Dm444 ${contents}/usr/share/applications/ai.storyteller.photocraft.desktop \
          $out/share/applications/ai.storyteller.photocraft.desktop
        cp -r ${contents}/usr/share/icons $out/share/
      '';
    })
  ];
}
