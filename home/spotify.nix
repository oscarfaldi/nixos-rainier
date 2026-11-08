{ pkgs, ... }:

{
  # Spotify desktop, patched by SpotX during the build (see the spotx-nix input in
  # flake.nix). On a free account that removes audio, banner and video ads and flips the
  # client's premium check, so skipping is unlimited and playback is on demand.
  #
  # What it cannot give back is enforced by Spotify's servers rather than the client:
  # offline downloads, 320 kbps, and streaming to a second device. No client patch
  # reaches those, so they will not start working after a rebuild.
  #
  # Nothing about the login is declared here, unlike ZapZap's settings: the credentials
  # are an encrypted autologin.blob inside ~/.config/spotify/prefs, which the client
  # rewrites on every exit - a store symlink would break that write. The profile is
  # snapshotted to the NAS by `session-backup` and restored by ./install instead.
  #
  # The package lives HERE, not in modules/packages.nix, on purpose: one file owns the
  # whole app, so deleting this file removes Spotify completely - no second place to
  # clean up.
  home.packages = [ pkgs.spotify-spotx ];
}
