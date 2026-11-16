{ config, lib, pkgs, ... }:

{
  # RDP connection profiles for the machines on the LAN.
  #
  # Naming, in case this repo outlives my memory: Rainier is the desktop, Glacier is a
  # VM, Cascade is the NAS. All mountains.
  #
  # Seeded through home.activation, deliberately NOT home.file: Remmina rewrites a
  # profile whenever it is saved, so a store symlink would either break that write or
  # be restored over the app own changes on every activation. Same pattern as
  # zapzap.nix. The seed only runs when the profile does not exist yet - after that
  # Remmina owns the file and edits made in the UI survive.
  #
  # Passwords never live here. Remmina keeps them in the GNOME keyring, so tick
  # "Save password" on the first connect and later launches go straight through.
  #
  # windows-glacier is the only RDP target. rainier runs Niri, which has no RDP server.

  home.activation.remminaSeedProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] "
    dir=\"$HOME/.local/share/remmina\"
    run mkdir -p \"$dir\"

    if [ ! -e \"$dir/windows-glacier.remmina\" ]; then
      run install -m 600 ${./remmina/windows-glacier.remmina} \"$dir/windows-glacier.remmina\"
    fi
  ";
}
