{ inputs, ... }:
{
  # Millennium (Steambrew) — Steam client mod loader.
  # The overlay exposes `pkgs.millennium-steam`, which hosts set as
  # `programs.steam.package` to replace the stock Steam client.
  flake.nixosModules.millennium = {
    nixpkgs.overlays = [ inputs.millennium.overlays.default ];
  };
}
