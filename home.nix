{ config, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    terminus_font
    playerctl
  ];
  imports = [
    ./sway.nix 
    ./waybar.nix
    ./foot.nix
    ./mako.nix
  ];
}
