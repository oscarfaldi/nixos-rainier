{ config, lib, pkgs, ... }:

{
  # Remote access profiles for the machines on the LAN, all in one client.
  #
  # Naming, in case this repo outlives my memory: Rainier is the desktop, Glacier is a
  # VM, Cascade is the NAS. All mountains.
  #
  # Remmina is protocol agnostic, so both VMs land in the same connection list:
  #
  #   nixos-glacier   -> VNC to 10.10.10.10:5900, the QEMU display Unraid already runs
  #   windows-glacier -> RDP to 10.10.10.175, the RDP server built into Windows
  #
  # The NixOS VM gets VNC rather than RDP on purpose. Its RDP server would be xrdp, an
  # extra pair of systemd units with known dbus/keyring quirks under XFCE - bolted onto
  # the machine this desktop depends on for reinstalls. QEMU already exposes a VNC
  # display for every VM, so VNC costs nothing to enable.
  #
  # Seeded through home.activation, deliberately NOT home.file: Remmina rewrites a
  # profile whenever it is saved, so a store symlink would either break that write or
  # be restored over the app own changes on every activation. Same pattern as
  # zapzap.nix. The seed only runs when the profile does not exist yet - after that
  # Remmina owns the file and edits made in the UI survive.
  #
  # Passwords never live here. Remmina keeps them in the GNOME keyring, so tick
  # "Save password" on the first connect and later launches go straight through.

  home.activation.remminaSeedProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] "
    dir=\"$HOME/.local/share/remmina\"
    run mkdir -p \"$dir\"

    seed() {
      if [ ! -e \"$dir/$1\" ]; then
        run install -m 600 \"$2\" \"$dir/$1\"
      fi
    }

    seed nixos-glacier.remmina ${./remmina/nixos-glacier.remmina}
    seed windows-glacier.remmina ${./remmina/windows-glacier.remmina}
  ";
}
