{ config, pkgs, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # A fresh install already has ~/.config/user-dirs.dirs (xdg-user-dirs writes it at first login),
    # and Home Manager refuses to overwrite a file it did not create - the whole activation aborts.
    # Backing the file up keeps the first activation working instead of needing a manual mv.
    backupFileExtension = "hm-backup";

    users.${config.my.username} = import ../home;
  };

  # Home Manager's activation runs as the user and refuses to start when neither per-user profile
  # directory exists - which is the state of a freshly installed machine. systemd-tmpfiles runs before
  # the home-manager service, so both paths (and their parents, with the right owner) are guaranteed.
  systemd.tmpfiles.rules = [
    "d ${config.my.home}/.local 0755 ${config.my.username} users -"
    "d ${config.my.home}/.local/state 0755 ${config.my.username} users -"
    "d ${config.my.home}/.local/state/nix 0755 ${config.my.username} users -"
    "d ${config.my.home}/.local/state/nix/profiles 0755 ${config.my.username} users -"
  ];
}
