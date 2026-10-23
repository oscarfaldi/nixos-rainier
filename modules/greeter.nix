{ config, pkgs, ... }:

let
autoLogin = false;
username = config.my.username;
in
{
services.greetd = {
enable = true;

settings.default_session =
  if autoLogin then {
    user = username;
    command = "niri-session-safe";
  } else {
    user = "greeter";
    command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd niri-session-safe";
  };

};

environment.systemPackages = with pkgs; [
tuigreet
];

  # Started by niri-session-safe only when the real config fails to validate. It keeps a terminal and
  # a config reload reachable, so a broken config can never leave the session without keybinds.
  environment.etc."niri/emergency.kdl".source = ./niri-emergency.kdl;
}
