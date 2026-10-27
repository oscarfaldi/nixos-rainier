# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Hardware configuration
      ./hardware-configuration.nix

      # Modules
      ./modules/audio.nix
      ./modules/appearance.nix
      ./modules/home.nix
      ./modules/greeter.nix
      ./modules/polkit.nix
      ./modules/packages.nix
      ./modules/network.nix
      ./modules/nvidia.nix
      ./modules/identity.nix
      ./modules/theme-seed.nix
      ./modules/tmpfs.nix
      ./modules/keyboard.nix
      ./modules/lock.nix
      ./modules/edge-policy.nix
      ./modules/pwa-edge.nix
      ./modules/games.nix
      ./modules/content-creation.nix
      ./modules/syncthing.nix
      ./modules/localsend.nix
      ./modules/smb-kernel-mount.nix

      # Scripts
      ./modules/scripts/systems-tool.nix
      ./modules/scripts/themes-tool.nix
      ./modules/scripts/actions-tool.nix
      ./modules/scripts/launchers-tool.nix
      ./modules/scripts/apps-tool.nix
    ];

  # Enable flakes and error experimental with new Nix CLI
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # NetworkManager for internet / normal LAN
  networking.networkmanager.enable = true;

  # Cloudflare WARP for VPN enabler
  services.cloudflare-warp.enable = true;

  networking.hostName = "rainier"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "Asia/Jakarta";

  # Power management daemon
  services.upower.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.my.username} = {
    isNormalUser = true;
    description = config.my.fullName;
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];

    # Let Hermes Agent (running on the NAS) SSH into this user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwwdQhkFTuiUfSjYqHW6nEw67VZJ7+kozdpZ4vuZKKk hermes-container@unraid"
    ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Configure Glacier as the primary Nix binary cache.
  nix.settings = {
    substituters = [
      "http://10.10.10.132:8501"
      "https://cache.nixos.org/"
    ];

    trusted-public-keys = [
      "glacier:UzkmMZRtnjiYaNB/X8Guih4cdla1RDkkNRhJVgeGKCk="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];

    trusted-substituters = [
      "http://10.10.10.132:8501"
      "https://cache.nixos.org/"
    ];

    narinfo-cache-negative-ttl = 0;
  };

  # ZRAM: compressed RAM swap, 50% ceiling (~16GB, safety net for heavy browsing)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
  
  # High swappiness since zram is RAM-to-RAM, not disk-backed
  boot.kernel.sysctl."vm.swappiness" = 180;
  
  # OOMD: kills worst memory offender (e.g. leaking Chromium tab) before system freezes
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };
  
  systemd.oomd.settings.OOM = {
    DefaultMemoryPressureDurationSec = "20s";
  };
  
  # CPU governor: max frequency always, no ramp-up latency on bursty builds
  powerManagement.cpuFreqGovernor = "performance";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;


  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
