# Shared system config for all hosts
{ config, lib, pkgs, ... }:
{
  networking.networkmanager.enable = true;
  time.timeZone = "America/Los_Angeles";
  users.users.madeline = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };
  programs.bash.interactiveShellInit = ''
    nixpush() {
      cd ~/Nix && \
      git add . && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
    nixsync() {
      cd ~/Nix && \
      git pull && \
      sudo nixos-rebuild switch --flake .#$(hostname)
    }
    nixup() {
      cd ~/Nix && \
      git add . && \
      sudo nixos-rebuild switch --flake .#$(hostname) && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
  '';
  programs.firefox.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.warn-dirty = false;
  system.stateVersion = "26.05";
}
