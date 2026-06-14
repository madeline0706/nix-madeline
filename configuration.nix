# Dell Pro 14 NixOS config

{ config, lib, pkgs, ... }:
{
  programs.sway.enable = true;
  services.displayManager.ly.enable = true;
  environment.systemPackages = with pkgs; [
    waybar
    fastfetch
    git
    pulsemixer
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
      git add . && \
      sudo nixos-rebuild switch --flake .#arcanine-nix && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
  '';

  # Hey hey thats me
  users.users.madeline = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    packages = with pkgs; [
      tree
    ];
  };

xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-wlr
    xdg-desktop-portal-termfilechooser
  ];
  config.common = {
    "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
  };
};




  # The best browser
  programs.firefox.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # PipeWire
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  system.stateVersion = "26.05";
}
