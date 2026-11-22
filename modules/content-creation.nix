{ pkgs, ... }:

# Editor-agnostic creative helpers: they stay whichever editor he settles on.
#   auto-editor  rough cut by audio silence, exports a timeline for the editor
#   whisper      faster-whisper env for the two transcribe actions (large-v3-turbo);
#                transcribe-video    = Indonesian only, prompts and language hardcoded to id
#                transcribe-video-en = English only, prompts and language hardcoded to en
#                Both accept the same audio/video files; neither auto-detects or mixes languages.
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
