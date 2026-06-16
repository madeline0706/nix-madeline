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
      mkHost = { system, hostname, extraModules ? [], homeModules ? [] }:
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
              home-manager.users.madeline = { imports = [ ./modules/home ] ++ homeModules; };
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        arcanine-nix = mkHost {
          system = "x86_64-linux";
          hostname = "arcanine-nix";
          homeModules = [ ./hosts/arcanine-nix/displays.nix ];
        };

        bulbasaur-nix = mkHost {
          system = "x86_64-linux";
          hostname = "bulbasaur-nix";
          homeModules = [ ./hosts/bulbasaur-nix/displays.nix ];
        };
      };
    };
}
