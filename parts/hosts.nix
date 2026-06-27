{ inputs, lib, config, ... }: {
  options = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.system = lib.mkOption { type = lib.types.str; default = "x86_64-linux"; };
      });
    };

    flake.homeModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = {};
    };
  };

  config = {
    hosts = {
      arcanine-nix.system = "x86_64-linux";
      bulbasaur-nix.system = "x86_64-linux";
    };

    flake.nixosConfigurations = lib.mapAttrs (host: cfg:
      inputs.nixpkgs.lib.nixosSystem {
        inherit (cfg) system;
        modules = [
          "${inputs.self}/hosts/${host}/configuration.nix"
          inputs.nyx.nixosModules.default
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.madeline.imports =
              builtins.attrValues config.flake.homeModules;
          }
        ] ++ builtins.attrValues config.flake.nixosModules;
      }
    ) config.hosts;
  };
}
