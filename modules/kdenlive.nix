{ pkgs, ... }:

# kdenlive — KDE's video editor, the incumbent while FilmCraft is on trial.
# Split into its own file so dropping it is a two-step: delete this file, delete its
# import line. auto-editor and whisper live in content-creation.nix and survive that.
#
# Removal: delete this file and its line in the configuration.nix imports list.

{
  environment.systemPackages = [
    pkgs.kdePackages.kdenlive
  ];
}
