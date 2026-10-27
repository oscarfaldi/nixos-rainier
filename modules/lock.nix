{ ... }:

# PAM service used by the Quickshell lock screen (Quickshell.Services.Pam, config = "qs-lock").
#
# Left at the NixOS default on purpose: `pam_unix` + `pam_env`, the same stack `login` uses, so the
# unlock prompt accepts exactly the password the greeter accepts. Writing the stack by hand buys
# nothing here and is the one thing that can lock someone out of their own machine.
{
  security.pam.services.qs-lock = { };
}
