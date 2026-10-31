{ pkgs, ... }:

# ============================================================
# Wine / Proton: running Windows game binaries
# ============================================================
#
# Standalone on purpose. This is the only file that decides how Windows
# executables run here, so the runtime is never smeared across packages.nix.
#
# Steam is used as a harness here, not as a store. Nothing is bought, no game
# account is involved, and a cracked release stays exactly what it is: the .exe
# gets a shortcut, Steam only provides the engine that runs it. It is already
# installed for CS2, and it is the practical way to get Proton on NixOS because
# it is the only thing shipping Proton together with the FHS runtime Proton
# needs. A bare Proton build cannot even start here - NixOS has no
# /lib64/ld-linux, so executing it directly fails with
# NixOS cannot run dynamically linked executables.
#
# The runtime is Proton through Steam, not a bare Wine installation:
#
# - Steam already ships Proton, keeps one prefix per game under
#   steamapps/compatdata, and bundles DXVK/VKD3D, so Direct3D work is done
#   without extra wiring.
# - GE-Proton adds the game-specific fixes that upstream Proton has not merged
#   (media foundation codecs, launcher workarounds). Non-Steam releases are
#   exactly the case that needs them, and declaring it here means it survives a
#   reinstall instead of being downloaded by hand into the Steam directory.
# - protontricks runs installers and winetricks verbs inside the prefix of an
#   existing game entry, so there is no second prefix to maintain. A bare Wine
#   install would only add a parallel environment that drifts from Proton.
#
# Usage:
#   1. Steam -> Games -> Add a Non-Steam Game, point it at the game's .exe
#   2. Properties -> Compatibility -> force GE-Proton
#   3. Launch it once, then: protontricks <appid> -c 'wine setup.exe' for
#      installers, or protontricks <appid> for the verb menu
#
# Removal: drop this file and its line in configuration.nix. Steam keeps
# working with its own Proton, only GE-Proton disappears from the dropdown.

{
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  environment.systemPackages = [
    # Per-game prefix maintenance: installers, winetricks verbs, misc DLL swaps.
    pkgs.protontricks
  ];
}
