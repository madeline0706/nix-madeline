{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  home-manager.users.madeline.imports = [ ./displays.nix ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; #to build pi 5 image
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "bulbasaur-nix";

  programs.steam.enable = true;

  # DRM Log noise in Ly
  boot.consoleLogLevel = 3;
  # AMD GPU
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
