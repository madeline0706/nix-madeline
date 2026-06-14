{ config, pkgs, ... }:
{
  home.stateVersion = "26.05";

  imports = [
    ./sway.nix
    ./waybar.nix
    ./foot.nix
  ];
}
