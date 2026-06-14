{ config, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    terminus_font
    playerctl
    libnotify
    arrpc
    lf
    bemenu
    j4-dmenu-desktop
  ];
  imports = [
    ./sway.nix 
    ./waybar.nix
    ./foot.nix
    ./mako.nix
    ./scripts.nix
  ];
}
