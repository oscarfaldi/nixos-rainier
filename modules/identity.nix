# One place that knows who this machine belongs to.
#
# Everything else reads `config.my.*`: the account, the Home Manager user, git identity, the greeter,
# the theme seed and the PWA icons. Changing the name means changing one value here - and `./install`
# rewrites it from $USER on the machine it runs on, so a clone always bootstraps the local user without
# manual editing.
#
# The repo path is derived, not configured: the clone always lands in the user's own ~/System.
{ lib, config, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.my = {
    username = mkOption {
      type = types.str;
      default = "oscarfaldi";
      description = "Login name of the owner account. install rewrites this to $USER.";
    };

    fullName = mkOption {
      type = types.str;
      default = "Oscar Faldi";
      description = "Display name: account description, git commits, greeter.";
    };

    email = mkOption {
      type = types.str;
      default = "oscarfaldi@gmail.com";
      description = "Git commit email.";
    };

    home = mkOption {
      type = types.str;
      readOnly = true;
      default = "/home/${config.my.username}";
      description = "Home directory, derived from the login name.";
    };

    repoPath = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.my.home}/System";
      description = "Where the repository is cloned. Fixed by convention, not by config.";
    };
  };
}
