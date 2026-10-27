{ ... }:

{
  programs.starship.settings = {
    # The palette is filled in at runtime by theme-apply
    # was rebuilt. Every style below references these names (color_orange, color_fg0, ...), so
    # without them starship renders the prompt with no colours at all.
    palette = "gruvbox_dark";

    palettes.gruvbox_dark = {
      color_fg0 = "#fbf1c7";
      color_bg1 = "#3c3836";
      color_bg3 = "#665c54";

      color_red = "#cc241d";
      color_green = "#98971a";
      color_yellow = "#d79921";
      color_blue = "#458588";
      color_purple = "#b16286";
      color_aqua = "#689d6a";
      color_orange = "#d65d0e";
    };


    # ============================================================
    # Prompt Format
    # ============================================================

    format = builtins.concatStringsSep "" [
      "[](color_orange)"
      "$os"
      "$username"
      "$hostname"
      "[](bg:color_yellow fg:color_orange)"
      "$directory"
      "[](fg:color_yellow bg:color_aqua)"
      "$git_branch"
      "$git_status"
      "[](fg:color_aqua bg:color_blue)"
      "$nodejs"
      "$python"
      "$rust"
      "$golang"
      "$php"
      "[](fg:color_blue bg:color_purple)"
      "$nix_shell"
      "[](fg:color_purple bg:color_bg3)"
      "$docker_context"
      "$cmd_duration"
      "[](fg:color_bg3 bg:color_bg1)"
      "$status"
      "$time"
      "[ ](fg:color_bg1)"
      "$line_break"
      "$line_break"
      "$character"
    ];


    # ============================================================
    # OS
    # ============================================================

    os = {
      disabled = false;
      style = "bg:color_orange fg:color_fg0";
    };

    os.symbols = {
      Windows = "󰍲";
      Ubuntu = "󰕈";
      SUSE = "";
      Raspbian = "󰐿";
      Mint = "󰣭";
      Macos = "󰀵";
      Manjaro = "";
      Linux = "󰌽";
      Gentoo = "󰣨";
      Fedora = "󰣛";
      Alpine = "";
      Amazon = "";
      Android = "";
      AOSC = "";
      Arch = "󰣇";
      Artix = "󰣇";
      EndeavourOS = "";
      CentOS = "";
      Debian = "󰣚";
      Redhat = "󱄛";
      RedHatEnterprise = "󱄛";
      Pop = "";
    };


    # ============================================================
    # Username
    # ============================================================

    username = {
      show_always = true;
      style_user = "bg:color_orange fg:color_fg0";
      style_root = "bg:color_orange fg:color_fg0";
      format = "[ $user ]($style)";
    };


    # ============================================================
    # Hostname
    # ============================================================

    hostname = {
      ssh_only = false;
      style = "bg:color_orange fg:color_fg0";
      format = "[@ $hostname ]($style)";
    };


    # ============================================================
    # Directory
    # ============================================================

    directory = {
      style = "fg:color_fg0 bg:color_yellow";
      format = "[ $path ]($style)";
      truncation_length = 5;
      truncation_symbol = "…/";
    };

    directory.substitutions = {
      Documents = "󰈙 ";
      Downloads = " ";
      Music = "󰝚 ";
      Pictures = " ";
      Developer = "󰲋 ";
    };


    # ============================================================
    # Git Branch
    # ============================================================

    git_branch = {
      symbol = "";
      style = "bg:color_aqua";
      format = "[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)";
    };


    # ============================================================
    # Git Status
    # ============================================================

    git_status = {
      style = "bg:color_aqua";

      ahead = "⇡\${count}";
      behind = "⇣\${count}";
      diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";

      modified = "!\${count}";
      staged = "+\${count}";
      deleted = "✘\${count}";
      untracked = "?\${count}";

      format = "[[(\$all_status\$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)";
    };


    # ============================================================
    # Node.js
    # ============================================================

    nodejs = {
      symbol = "";
      style = "bg:color_blue";
      format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
    };


    # ============================================================
    # Python
    # ============================================================

    python = {
      symbol = "";
      style = "bg:color_blue";
      format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
    };


    # ============================================================
    # Rust
    # ============================================================

    rust = {
      symbol = "";
      style = "bg:color_blue";
      format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
    };


    # ============================================================
    # Golang
    # ============================================================

    golang = {
      symbol = "";
      style = "bg:color_blue";
      format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
    };


    # ============================================================
    # PHP
    # ============================================================

    php = {
      symbol = "";
      style = "bg:color_blue";
      format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
    };


    # ============================================================
    # Nix Shell
    # ============================================================

    nix_shell = {
      symbol = "";
      style = "bg:color_purple fg:color_green";
      format = "[[ $symbol $name ]($style)]";
    };


    # ============================================================
    # Docker
    # ============================================================

    docker_context = {
      symbol = "";
      style = "bg:color_bg3";
      format = "[[ $symbol( $context) ](fg:color_fg0 bg:color_bg3)]($style)";
    };


    # ============================================================
    # Command Duration
    # ============================================================

    cmd_duration = {
      min_time = 2000;
      show_milliseconds = false;

      style = "bg:color_bg3";

      format = "[[  $duration ](fg:color_fg0 bg:color_bg3)]($style)";
    };


    # ============================================================
    # Command Status
    # ============================================================

    status = {
      disabled = false;

      symbol = "✘";
      success_symbol = "";

      style = "bg:color_bg1";

      format = "[[ $symbol $status ](fg:color_fg0 bg:color_red)]($style)";
    };


    # ============================================================
    # Time
    # ============================================================

    time = {
      disabled = false;

      time_format = "%R";

      style = "bg:color_bg1";

      format = "[[  $time ](fg:color_fg0 bg:color_bg1)]($style)";
    };


    # ============================================================
    # Line Break
    # ============================================================

    line_break.disabled = false;


    # ============================================================
    # Character
    # ============================================================

    character = {
      disabled = false;

      success_symbol = "[](bold fg:color_green)";
      error_symbol = "[](bold fg:color_red)";

      vimcmd_symbol = "[](bold fg:color_green)";
      vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
      vimcmd_replace_symbol = "[](bold fg:color_purple)";
      vimcmd_visual_symbol = "[](bold fg:color_yellow)";
    };
  };
}
