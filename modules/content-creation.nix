{ pkgs, ... }:

# Editor-agnostic creative helpers: they stay whichever editor he settles on.
#   auto-editor  rough cut by audio silence, exports a timeline for the editor
#   whisper      faster-whisper env for the transcribe-video action (large-v3-turbo)
# The editors themselves live in their own modules (filmcraft.nix, photocraft.nix)
# so any one of them can be dropped in one step.
#
# Removal: delete this file and its line in the configuration.nix imports list.

{
  environment.systemPackages = [
    # ============================================================
    # Rough Cutting
    # ============================================================
    pkgs.auto-editor

    # ============================================================
    # AI Subtitle Generation
    # ============================================================
    (pkgs.python313.withPackages (ps: [
      ps.faster-whisper
    ]))
  ];
}
