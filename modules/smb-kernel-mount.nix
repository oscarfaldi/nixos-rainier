{ config, lib, pkgs, ... }:

let
  # The IP or Hostname of your NAS
  nasIp = "10.10.20.10";

  # List of all your NAS share folders
  nasShares = [
    "oscarfaldi"
    "personalbranding"
    "mulino"
    "academy"
    "family"
    "download"
    "games"
    "media-music"
    "media-video"
    "toolkit"
    "snapshot"
    "valhalla"
    "archive"
    "appdata"
  ];

  # Common CIFS mount options shared by all mounts
  commonOptions = [
    "credentials=/etc/smb-credentials"

    "vers=3.1.1"
    "noserverino"

    "uid=1000"
    "gid=100"
    "file_mode=0664"
    "dir_mode=0775"

    "_netdev"
    "nofail"

    # Mount on access instead of connecting to the NAS during boot.
    "x-systemd.automount"

    # Release a share once nothing has used it for ten minutes.
    #
    # `0` (never unmount) keeps a dead session attached forever: when the NAS reboots or the link
    # flaps, the mount stays "connected" to a session that no longer exists, every later access
    # blocks in the kernel, and only rebooting the NAS cleared it. With a finite timeout the idle
    # mount is released and the next access opens a FRESH session, so the machine heals itself.
    # systemd refuses to unmount while a file is open, so nothing gets cut mid-work.
    "x-systemd.idle-timeout=10min"

    # Detect an unresponsive SMB connection faster.
    "echo_interval=5"

    # Return an error instead of retrying forever when the server stops answering. `soft` is the
    # documented knob for that; `timeo=`/`retrans=` are NOT accepted by this kernel and cifs-utils
    # (mount error 22, "Unknown parameter"), so they are deliberately absent. Dead sessions are
    # detected by echo_interval instead, and cleared by the idle timeout above.
    "soft"

    "x-systemd.mount-timeout=5s"
  ];
in
{
  # Dynamically map the share list into the fileSystems attribute set
  fileSystems = lib.genAttrs (map (s: "/mnt/nas/${s}") nasShares) (mountPoint:
    let
      share = lib.removePrefix "/mnt/nas/" mountPoint;
    in
    {
      device = "//${nasIp}/${share}";
      fsType = "cifs";
      options = commonOptions;
    }
  );
}
