{ config, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      # ============================================================
      # Font
      # ============================================================

      font-family = "JetBrainsMono Nerd Font";
      font-size = 12;
      font-thicken = true;

      # ============================================================
      # Cursor
      # ============================================================

      cursor-style = "block";
      cursor-style-blink = false;

      # ============================================================
      # Shader
      # ============================================================

      custom-shader = "shaders/cursor_warp.glsl";
      custom-shader-animation = "always";

      # ============================================================
      # Theme
      # ============================================================

      # Only this POINTER is static. theme-apply writes the palette to that path, so a theme switch
      # is a file write plus a reload - never a rebuild.
      theme = "${config.xdg.stateHome}/theme/ghostty";

      # ============================================================
      # Appearance
      # ============================================================

      background-opacity = 0.75;
      background-blur-radius = 50;

      window-padding-x = 12;
      window-padding-y = 12;

      # ============================================================
      # Behavior
      # ============================================================

      mouse-hide-while-typing = true;
      window-save-state = "always";

      # ============================================================
      # Navigation
      # ============================================================

      keybind = [
        "ctrl+h=goto_split:left"
        "ctrl+j=goto_split:bottom"
        "ctrl+k=goto_split:top"
        "ctrl+l=goto_split:right"

        "super+h=previous_tab"
        "super+l=next_tab"

        "super+ctrl+h=resize_split:left,10"
        "super+ctrl+j=resize_split:down,10"
        "super+ctrl+k=resize_split:up,10"

        "shift+enter=text:\\n"
      ];
    };
  };
}
