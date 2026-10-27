{ osConfig, ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = osConfig.my.fullName;
      email = osConfig.my.email;
    };
  };
}
