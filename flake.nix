{
  description = "Madeline's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHost = { system, hostname, extraModules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/${hostname}/configuration.nix
            ./modules/system/common.nix
            ./modules/system/desktop.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.madeline = import ./modules/home;
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        arcanine-nix = mkHost {
          system = "x86_64-linux";
          hostname = "arcanine-nix";
        };

        bulbasaur-nix = mkHost {
          system = "x86_64-linux";
          hostname = "bulbasaur-nix";
        };
      };
    };
}
