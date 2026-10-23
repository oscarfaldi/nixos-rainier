{ config, pkgs, lib, ... }:

{
  xdg = {
    enable = true;

    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;

      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      videos = "$HOME/Videos";
      # null = not written to user-dirs.dirs at all, so the desktop never creates the folder.
      # Same mechanism as templates below.
      templates = null;
      publicShare = null;
    };

    mime.enable = true;
  };

  # Activation script to ensure extra directories exist
  home.activation.createGamesDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/Games"
    '';
}
