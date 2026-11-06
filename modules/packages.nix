{ config, pkgs, ... }:

{
  # ============================================================
  # Desktop Environment
  # ============================================================

  # Enable niri as a compositor or window manager
  programs.niri.enable = true;

  # Enable dconf for GTK applications and settings persistence
  programs.dconf.enable = true;

  # Enable xfconf for saving thunar configuration
  programs.xfconf.enable = true;

  # Enable dbus system
  services.dbus.enable = true;

  # Enable thumbnail for thunar
  services.tumbler.enable = true;

  # Virtual filesystem support (USB, trash, network shares, sidebar integration)
  services.gvfs.enable = true;

  # USB automount and removable media support
  services.udisks2.enable = true;

  # GNOME keyring for credentials and secrets
  services.gnome.gnome-keyring.enable = true;

  # Polkit lives in modules/polkit.nix (framework, pkexec wrapper, power-action rules).

  # ZSH enable
  programs.zsh.enable = true;

  # ============================================================
  # Optional Services
  # ============================================================

  # Bluetooth
  # hardware.bluetooth = {
  #   enable = true;
  #   powerOnBoot = true;
  # };

  # Bluetooth GUI
  # services.blueman.enable = true;

  # ============================================================
  # Desktop Applications
  # ============================================================

  environment.systemPackages = with pkgs; [

    # ------------------------------------------------------------
    # Core Desktop
    # ------------------------------------------------------------

    xdg-utils
    networkmanagerapplet
    polkit_gnome

    # ------------------------------------------------------------
    # Terminal & Development
    # ------------------------------------------------------------

    bash

    git
    nano
    wget

    ghostty
    neovim

    # ------------------------------------------------------------
    # Terminal Utilities
    # ------------------------------------------------------------

    fastfetch
    btop
    nvd

    zoxide
    eza
    bat
    fzf
    ripgrep
    fd
    tree

    jq
    yq-go

    # starship comes from programs.starship (home/shell.nix); listing it here would
    # install the same package twice.

    man-pages
    man-pages-posix

    # ------------------------------------------------------------
    # Networking & Troubleshooting
    # ------------------------------------------------------------
    
    curl
    openssl
    dnsutils
    tcpdump
    ethtool
    netcat

    # ------------------------------------------------------------
    # Niri Ecosystem
    # ------------------------------------------------------------

    xwayland-satellite

    # notify-send stays: services/Notifier.qml uses it to deliver the shell's own
    # notifications, and it is the tool used to test the notification server.
    libnotify

    quickshell

    # the niri keybind and swayidle need no change. It is required here because
    swayidle

    # ------------------------------------------------------------
    # File Management & Documents
    # ------------------------------------------------------------


    yazi

    engrampa

    zip
    unzip
    p7zip
    unrar

    atril
    pdfarranger
    poppler-utils
    pandoc
    tectonic
    img2pdf

    libreoffice
    obsidian
    mousepad

    cifs-utils
    nfs-utils
    rsync

    # ------------------------------------------------------------
    # Media
    # ------------------------------------------------------------

    mpv
    mpvScripts.uosc
    mpvScripts.thumbfast
    mpvScripts.builtins.autoload

    qimgv
    imagemagick

    ffmpeg
    ffmpegthumbnailer

    exiftool

    libwebp
    libavif
    librsvg
    libgepub
    libopenraw
    libgsf

    grim
    slurp

    # ------------------------------------------------------------
    # Messaging
    # ------------------------------------------------------------

    # Discord, official client. Its profile in ~/.config/discord carries the session
    # token, so session-backup snapshots it to the NAS and install restores it: a
    # reinstall opens already logged in, with no "verify this new device" email.
    discord

    # Telegram, official desktop client. tdata/ holds the login the same way.
    telegram-desktop

    # ZapZap (WhatsApp). The package lives here with the other clients; home/zapzap.nix
    # keeps only the activation that seeds its settings file into $HOME, which is the
    # one thing a system package cannot do.
    zapzap

    # ------------------------------------------------------------
    # System Controls
    # ------------------------------------------------------------


    wl-clipboard

    brightnessctl
    playerctl

    gnome-calculator


    nvibrant


    smartmontools
    gnome-disk-utility
    ntfs3g
    exfatprogs
    parabolic

    # ------------------------------------------------------------
    # System Diagnostics
    # ------------------------------------------------------------
    
    lsof
    strace
    pciutils

    # ------------------------------------------------------------
    # Qt Wayland
    # ------------------------------------------------------------

    qt5.qtwayland
    qt6.qtwayland
  ];
}
