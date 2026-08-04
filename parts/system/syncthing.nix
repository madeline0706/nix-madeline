{ ... }: {
  flake.nixosModules.syncthing = { config, lib, ... }:
  let
    # Each device's ID is shown in the web UI (localhost:8384) under
    # Actions -> Show ID, or via `syncthing --device-id` on that host.
    # Fill these in once after the first rebuild (see notes below).
    allDevices = {
      shiva        = "A6W4X4N-JA6WJPR-GXO3CXO-BCDX5SZ-5VJA6ZM-6ADL6SV-WPM7H5A-24AGYQH";
      bulbasaur-nix = "BNQQRWV-QNCW2VP-JA3HKVD-LTTTPDS-KY7IS37-XYSMOTH-6QCFC6K-LNJCSAQ";
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

    # Ensure the sync target exists before syncthing scans it. `d` only
    # creates the directory when absent, so existing notes are left as-is.
    systemd.tmpfiles.rules = [
      "d /home/madeline/notes 0755 madeline users -"
    ];
  };
}
