{ pkgs, ... }:

{
  environment.systemPackages = [
    # ============================================================
    # Video Editing
    # ============================================================
    pkgs.kdePackages.kdenlive
    pkgs.auto-editor

    # ============================================================
    # AI Subtitle Generation
    # ============================================================
    (pkgs.python313.withPackages (ps: [
      ps.faster-whisper
    ]))
  ];
}
