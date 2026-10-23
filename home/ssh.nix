{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings.cascade = {
      HostName = "10.10.10.10";
      User = "root";
      IdentityFile = "~/.ssh/id_ed25519_cascade";
    };

    settings."github.com" = {
      User = "git";
      IdentityFile = "~/.ssh/id_ed25519_github";
      IdentitiesOnly = true;
    };
  };
}
