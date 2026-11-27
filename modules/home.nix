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

  # Activation loads dconf under a throwaway dbus session, because no user bus exists yet during
  # boot. dconf initializes GIO, GIO activates org.gtk.vfs.Daemon, and gvfsd then spawns gvfsd-fuse
  # on $HOME/.gvfs (the legacy location, chosen whenever XDG_RUNTIME_DIR is unset). When the
  # temporary bus exits, gvfsd-fuse dies mid-init and leaves that mount behind in
  # "Transport endpoint is not connected" state - after which Thunar fails to open the home
  # directory until the mount is removed by hand, on every boot that loses the race.
  # Pinning the local GIO backend for this unit stops the activation from touching gvfs at all.
  systemd.services."home-manager-${config.my.username}".environment.GIO_USE_VFS = "local";

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
