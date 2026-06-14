# Dell Pro 14 NixOS config

{ config, lib, pkgs, ... }:
{
  programs.sway.enable = true;
  services.displayManager.ly.enable = true;
  environment.systemPackages = with pkgs; [
    waybar
    fastfetch
    git
  ];

  imports =
    [
      ./hardware-configuration.nix
    ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "arcanine-nix";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Los_Angeles";

  # I am lazy
  programs.bash.interactiveShellInit = ''
    nixpush() {
      cd ~/nixos-config && \
      git add . && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
    nixup() {
      cd ~/nixos-config && \
      sudo nixos-rebuild switch && \
      git add . && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
  '';

  # Hey hey thats me
  users.users.madeline = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };

  # The best browser
  programs.firefox.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";
}
