{ ... }: {
  flake.nixosModules.syncthing = { config, lib, ... }:
  let
    # Each device's ID is shown in the web UI (localhost:8384) under
    # Actions -> Show ID, or via `syncthing --device-id` on that host.
    # Fill these in once after the first rebuild (see notes below).
    allDevices = {
      shiva        = "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
      bulbasaur-nix = "BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB-BBBBBBB";
    };
    self = config.networking.hostName;
    peers = lib.filterAttrs (n: _: n != self) allDevices;
  in {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true; # 22000/tcp+udp (transfers), 21027/udp (discovery)
      user = "madeline";
      group = "users";
      dataDir = "/home/madeline";
      configDir = "/home/madeline/.config/syncthing";

      # Make the Nix config the source of truth: devices/folders not
      # declared here get removed instead of lingering from the web UI.
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.mapAttrs (_: id: { inherit id; }) peers;
        folders.notes = {
          path = "/home/madeline/notes";
          devices = builtins.attrNames peers;
        };
      };
    };
  };
}
