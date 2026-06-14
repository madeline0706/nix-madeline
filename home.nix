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

xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
    xdg-desktop-portal-termfilechooser
  ];
  config.common."org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
};

  imports = [
    ./sway.nix 
    ./waybar.nix
    ./foot.nix
    ./mako.nix
    ./scripts.nix
  ];
}
