{ config, lib, pkgs, ... }:

let

  # Bash helpers: writeShellScriptBin prepends the bash shebang.
  mkScript = name:
    pkgs.writeShellScriptBin name
      (builtins.readFile ../../modules/scripts/themes/${name});

  # Python helpers need their OWN interpreter. Passing a .py file to mkScript produced a bash script
  # with python code inside, and the build died on the first line of python
  # ("syntax error near unexpected token `('"). The interpreter is pinned to the store so the tool
  # does not depend on python3 happening to be in PATH when theme-apply calls it.
  mkPython = name:
    pkgs.writeScriptBin name (''
      #!${pkgs.python3}/bin/python3
    '' + lib.replaceStrings [ "#!/usr/bin/env python3\n" ] [ "" ]
      (builtins.readFile ../../modules/scripts/themes/${name}));

in
{

  # ============================================================
  # Environment Scripts (Themes & Wallpaper)
  # ============================================================

  # Official palettes, read-only and system-wide. Lives in /etc on purpose: it is a plain symlink
  # into the store, so a leftover directory in $HOME can never make activation fail again.
  environment.etc."qs-palettes".source = ../../themes;

  environment.systemPackages = [
    (mkScript "wallpaper-session")
    # Ctrl+Tab: next background of the active theme
    (mkScript "wallpaper-next")
    # theme-apply is the switcher engine; theme-list/theme-current are read by it and by the
    # launcher menu, themes-menu builds the launcher rows.
    (mkScript "theme-apply")
    (mkScript "theme-list")
    (mkScript "theme-current")
    (mkScript "theme-next")
    (mkScript "themes-menu")
    # recolours a copied GTK theme from a palette (called by theme-apply)
    (mkPython "theme-gtk-recolor")
    # derives the starship prompt palette from a palette (called by theme-apply)
    (mkPython "theme-prompt-palette")
  ];
}
