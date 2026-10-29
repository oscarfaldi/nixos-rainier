{ config, lib, pkgs, ... }:

{
  # WhatsApp desktop client. The Edge PWA stays installed as a fallback, but the
  # wrapper is what runs in the session: it keeps a real tray icon, stays alive when
  # the window is closed, and keeps its web profile in a directory of its own - which
  # is what makes the WhatsApp link small enough to back up and restore.
  #
  # Only the settings are seeded here. The account itself is a WhatsApp linked device
  # whose credentials live in ~/.local/share/ZapZap; ./install restores that directory
  # from the NAS before the first launch, so a reinstall does not need a new QR scan.
  home.packages = [ pkgs.zapzap ];

  home.activation.zapzapSeedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="$HOME/.config/ZapZap/ZapZap.conf"
    if [ ! -e "$conf" ]; then
      run mkdir -p "$(dirname "$conf")"
      run install -m 600 ${./zapzap/ZapZap.conf} "$conf"
    fi
  '';
}
