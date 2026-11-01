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

  # ---------------------------------------------------------------- generated themes, at build time
  #
  # Palettes without a packaged GTK theme of their own (`generate_gtk`) used to be generated the
  # moment they were switched to, into ~/.local/share. That made a switch against a cold cache take
  # 22 s - the icon set alone was 21 s of it - and left a half-built theme behind if it was
  # interrupted. They are built HERE instead:
  #
  #   * the switch only points GTK at a store path, so it costs milliseconds and every palette is
  #     equally fast, including one that was never used before;
  #   * the result is immutable, reproducible, and present on a fresh install;
  #   * no runtime cache to go stale after a palette edit, and no lock contention with a switch.
  #
  # SAFETY, deliberately belt-and-braces: every step below is guarded, so a broken palette can never
  # turn into a refused rebuild. A theme that cannot be recoloured ships the base colours; a theme
  # whose gtk-3.0/gtk.css is missing is dropped from the output entirely, which makes theme-apply fall
  # back to generating it at runtime exactly as before. Quickshell does not read ANY of this - the
  # shell takes its colours from the palette JSON - so nothing here can take the bar or a popup down.
  paletteNames = builtins.attrNames (lib.filterAttrs
    (_: type: type == "directory")
    (builtins.readDir ../../themes));

  paletteValue = name: key:
    let
      lines = lib.splitString "\n" (builtins.readFile ../../themes/${name}/colors.toml);
      hit = line: builtins.match "[ \t]*${key}[ \t]*=[ \t]*\"([^\"]*)\".*" line;
      hits = builtins.filter (line: hit line != null) lines;
    in
    if hits == [ ] then "" else builtins.head (hit (builtins.head hits));

  wantsGtk = name: paletteValue name "generate_gtk" == "true";
  wantsIcons = name: paletteValue name "generate_icons" == "true";

  # The base theme is Nordic for every palette that generates one (see themes/*/colors.toml).
  mkStoreGtk = name: pkgs.runCommandLocal "qs-gtk-${name}" { } ''
    themeDir=$out/share/themes/qs-${name}

    mkdir -p "$themeDir"
    cp -rL ${pkgs.nordic}/share/themes/Nordic/. "$themeDir"/ \
      || echo "qs-gtk-${name}: could not copy the base theme" >&2
    chmod -R u+w "$themeDir" 2>/dev/null || true

    ${pkgs.python3}/bin/python3 ${./themes/theme-gtk-recolor} "$themeDir" ${../../themes/${name}/colors.toml} \
      || echo "qs-gtk-${name}: recolour failed, keeping the base colours" >&2

    sed -i "s/^Name=.*/Name=qs-${name}/" "$themeDir/index.theme" 2>/dev/null || true

    if [ ! -f "$themeDir/gtk-3.0/gtk.css" ]; then
      echo "qs-gtk-${name}: no gtk-3.0/gtk.css, dropping this theme" >&2
      rm -rf "$themeDir"
    fi
  '';

  mkStoreIcons = name: pkgs.runCommandLocal "qs-icons-${name}" { } ''
    mkdir -p $out/share/icons

    ${pkgs.python3}/bin/python3 ${./themes/theme-gen-icons} \
      ${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark \
      "$out/share/icons/qs-${name}" "qs-${name}" "${paletteValue name "icons_color"}" \
      || echo "qs-icons-${name}: generation failed, this palette keeps its packaged icons" >&2

    [ -d "$out/share/icons/qs-${name}" ] || rm -rf "$out/share/icons/qs-${name}"
  '';

  generatedThemePaths =
    lib.concatMap
      (name: lib.optional (wantsGtk name) (mkStoreGtk name)
        ++ lib.optional (wantsIcons name) (mkStoreIcons name))
      paletteNames;

  generatedThemes = pkgs.symlinkJoin {
    name = "qs-generated-themes";
    paths = generatedThemePaths;
  };

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
    # recolours a copied GTK theme from a palette (called by theme-apply, and by the build for the
    # generated themes above)
    (mkPython "theme-gtk-recolor")
    # builds a palette's icon theme; one process instead of ~6 per icon (called by theme-apply for
    # palettes that are not in the store, and by the build)
    (mkPython "theme-gen-icons")
    # derives the starship prompt palette from a palette (called by theme-apply)
    (mkPython "theme-prompt-palette")
  ] ++ lib.optional (generatedThemePaths != [ ]) generatedThemes;
}
