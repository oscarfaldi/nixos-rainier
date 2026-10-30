# ============================================================
# Game Storage
# ============================================================
#
# Purpose:
# - Keep Steam's client state and game library on a disk that survives a
#   NixOS reinstall: sda1 (ext4) mounted at /games.
# - Wire Steam's fixed paths to that disk with symlinks, so a fresh install
#   boots with the account logged in, the library detected and saves intact.
#
# Why symlinks: Steam cannot relocate its own data directory, and its config
# is mutable runtime state - it can never live in the read-only Nix store.
# A symlink is invisible to Steam and gets recreated by every rebuild.
#
# The disk is never touched by the installer: only nvme0n1 is reinstalled,
# /games lives on a separate physical device.
#
# ============================================================

{ config, lib, pkgs, ... }:

let
  inherit (config.my) username;
  gamesRoot = "/games";
  diskUuid = "d70e290f-21bc-45d5-b4e6-f9780236ef3c";
in
{
  # --------------------------------------------------
  # Persistent game disk
  # --------------------------------------------------
  # nofail:         an unplugged or dead disk must never block boot
  # device-timeout: give up after 10s instead of the 90s default
  # noatime:        skip access-time writes, less wear on the SSD
  fileSystems."${gamesRoot}" = {
    device = "/dev/disk/by-uuid/${diskUuid}";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=10" "noatime" ];
  };

  # --------------------------------------------------
  # Layout
  # --------------------------------------------------
  # /games/Steam          client state: login token, config.vdf, ssfn, userdata
  # /games/SteamLibrary   steamapps: installed games, Proton prefixes, saves
  #
  # A dedicated unit instead of systemd.tmpfiles.rules: tmpfiles runs after
  # local-fs.target but finishes well before /games is mounted during a
  # nixos-rebuild switch, so the directories would be created on the root
  # filesystem and hidden by the mount. Ordering after games.mount makes the
  # layout deterministic on both switch and boot.
  #
  # Steam's default library sits at <client>/steamapps, so that path is
  # redirected into SteamLibrary - otherwise the first launch would create it
  # on the root filesystem instead.
  systemd.services.games-storage-setup = {
    description = "Create the Steam directory layout on the persistent game disk";

    wantedBy = [ "multi-user.target" ];
    requires = [ "games.mount" ];
    after = [ "games.mount" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      install -d -o ${username} -g users -m 0755 \
        ${gamesRoot}/Steam \
        ${gamesRoot}/SteamLibrary \
        ${gamesRoot}/SteamLibrary/steamapps
      ln -sfn ${gamesRoot}/SteamLibrary/steamapps ${gamesRoot}/Steam/steamapps
    '';
  };

  # --------------------------------------------------
  # Symlinks
  # --------------------------------------------------
  # mkOutOfStoreSymlink: Home Manager owns the link, Steam owns the contents.
  # ~/Games keeps the path the existing cs2 script already expects.
  home-manager.users.${username} = { config, ... }: {
    home.file = {
      ".local/share/Steam".source =
        config.lib.file.mkOutOfStoreSymlink "${gamesRoot}/Steam";
      "Games".source =
        config.lib.file.mkOutOfStoreSymlink "${gamesRoot}/SteamLibrary";
    };
  };

  # --------------------------------------------------
  # Steam Guard codes without email
  # --------------------------------------------------
  # Package name is steamguard-cli, the installed binary is `steamguard`.
  environment.systemPackages = with pkgs; [ steamguard-cli ];
}
