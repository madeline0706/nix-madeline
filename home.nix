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
    cmd=${config.home.homeDirectory}/.config/xdg-desktop-portal-termfilechooser/lf-wrapper.sh
  '';

  xdg.configFile."xdg-desktop-portal-termfilechooser/lf-wrapper.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      multiple="$1"
      directory="$2"
      save="$3"
      path="$4"
      out="$5"
      foot --app-id=filechooser -- lf --chooser-file="$out" "$path"
    '';
  };
  imports = [
    ./sway.nix
    ./waybar.nix
    ./foot.nix
    ./mako.nix
    ./scripts.nix
  ];
}
