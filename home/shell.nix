{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Zsh
  # ============================================================

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    # zsh-autosuggestions: home-manager installs the plugin and wires it into .zshrc itself, so the
    # package no longer needs to sit in environment.systemPackages.
    autosuggestion.enable = true;

    # initContent is merged in order. compinit is generated at order 550, so an extra completion
    # directory has to be added to fpath BEFORE that (500) or its completions are never loaded.
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        # zsh-completions: additional site-functions shipped by the package.
        fpath+=("${pkgs.zsh-completions}/share/zsh/site-functions")
      '')

      (lib.mkOrder 600 ''
        # Aliases
        [ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"

        # Smart directory jumping
        command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
      '')

      (lib.mkOrder 700 ''
        # starship reads its palette from the theme state file, which theme-apply rewrites on every
        # switch; starship re-reads its config per prompt, so no shell or terminal restart is needed.
        if [[ -r "${config.xdg.stateHome}/theme/starship.toml" ]]; then
          export STARSHIP_CONFIG="${config.xdg.stateHome}/theme/starship.toml"
        else
          export STARSHIP_CONFIG="${config.xdg.configHome}/starship.toml"
        fi
      '')
    ];
  };

  # ============================================================
  # Starship
  # ============================================================

  programs.starship.enable = true;

}
