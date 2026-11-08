{
  description = "Rainier NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Patches the Spotify desktop client while its derivation is built: audio and banner
    # ads are skipped, and the premium flag is flipped for a free account. Pinned here so
    # the only maintenance is `nix flake update spotx-nix` after a Spotify bump.
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    spotx-nix,
    ...
  }: {
    nixosConfigurations.rainier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager

        # Provides pkgs.spotify-spotx to every system module and to Home Manager.
        { nixpkgs.overlays = [ spotx-nix.overlays.default ]; }
      ];
    };
  };
}
