# Shared desktop config
{ config, lib, pkgs, ... }:

{
  programs.sway.enable = true;

  services.displayManager.ly.enable = true;

  environment.systemPackages = with pkgs; [
    waybar
    fastfetch
    git
  ];
}
