{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];
  home-manager.users.madeline.imports = [ ./displays.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];
  nix.settings.trusted-users = [ "madeline" ];
  nix.settings.extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];
  networking.hostName = "bulbasaur-nix";
  programs.steam.enable = true;
  boot.consoleLogLevel = 3;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
