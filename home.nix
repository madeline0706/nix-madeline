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
    xdg-desktop-portal-termfilechooser
  ];

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=foot --app-id=filechooser -- lf
  '';

  imports = [
    ./sway.nix
    ./waybar.nix
    ./foot.nix
    ./mako.nix
    ./scripts.nix
  ];
}
