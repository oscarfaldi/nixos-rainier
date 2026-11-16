{ config, lib, pkgs, ... }:

{
  # RDP connection profiles for the LAN machines.
  #
  # Seeded through home.activation, deliberately NOT home.file: Remmina rewrites a
  # profile when it is saved, so a store symlink would either break that write or be
  # restored over the app own changes on every activation. Only created when the file
  # does not exist yet - after that the app owns it.
  #
  # Passwords are never kept here. Remmina stores them in the GNOME keyring, so tick
  # "Save password" on the first connect and later launches go straight through.
  #
  # Only the Windows VM speaks RDP. The NAS NixOS VM (10.10.10.132) is a headless nix
  # cache, and this desktop runs Niri which has no RDP server - so no profiles for them.

  home.activation.remminaSeedProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dir="$HOME/.local/share/remmina"
    mkdir -p "$dir"

    if [ ! -e "$dir/Windows-NAS.remmina" ]; then
      cat > "$dir/Windows-NAS.remmina" <<"PROFILE"
[remmina]
name=Windows NAS (SMTasker)
protocol=RDP
server=10.10.10.175
username=Oscar Faldi
domain=
colordepth=32
quality=9
cert_ignore=1
disablepasswordstoring=0
window_maximize=1
group=NAS
PROFILE
      chmod 600 "$dir/Windows-NAS.remmina"
    fi
  '';
}
