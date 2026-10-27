{
  config,
  pkgs,
  ...
}:

{
  # ============================================================
  # LocalSend
  #
  # AirDrop-style transfer between this machine and the phone, over the LAN only. The phone side is
  # the LocalSend app (F-Droid / Play Store) and needs no account, no cloud and no WhatsApp
  # compression.
  #
  # The desktop app listens on 53317 TCP (the transfer itself) and UDP (multicast discovery), so both
  # go into allowedTCPPorts/allowedUDPPorts. An `extraInputRules` rule scoped to 10.10.0.0/16 would be
  # tighter, but that option is only rendered when networking.nftables.enable is true, and this host
  # still uses the iptables backend - the rule would be silently dropped. Ports open on every
  # interface here, and every interface on this machine is a private LAN; nothing is reachable from the
  # internet because the router does NAT and forwards no port to this host. That is the same exposure
  # class as Syncthing's 22000, which is already open.
  #
  # Receiving is NOT automatic: leave "Quick Save" off in the app so every incoming file has to be
  # accepted. An open LAN port is uninteresting while a human still has to say yes.
  #
  # The launcher needs no entry: it lists DesktopEntries.applications, and the package installs
  # `localsend_app.desktop` like any other GUI app.
  #
  # Removal: delete this file, remove ./modules/localsend.nix from configuration.nix, rebuild. Nothing
  # else in the repo refers to it.
  # ============================================================

  environment.systemPackages = [ pkgs.localsend ];

  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];
}
