# Dell Pro 14 NixOS config
#
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boat
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hardware
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Power management
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  services.power-profiles-daemon.enable = false;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "ignore";
  };

  # Networking
  networking.hostName = "arcanine-nix";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;

  # Time
  time.timeZone = "America/Los_Angeles";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Greeter / WM
  services.displayManager.ly = {
    enable = true;
    settings = {
      session_log = "null";
    };
  };
  programs.sway.enable = true;

  # Audiojungle
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Terminal file picker
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-termfilechooser
    ];
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
    config.common = {
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  environment.sessionVariables = {
    GTK_USE_PORTAL = "1";
  };

  # PAM
  security.pam.services.waylock = {};

  # The best browser
  programs.firefox.enable = true;

  # Global packages
  environment.systemPackages = with pkgs; [
    git
    pulsemixer
    tailscale
  ];

  # Users
  users.users.madeline = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    packages = with pkgs; [
      tree
    ];
  };

  # Shell helpers (Shellpers)
  programs.bash.interactiveShellInit = ''
    nixpush() {
      cd ~/Nix && \
      git add . && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
    nixup() {
      cd ~/Nix && \
      git add . && \
      sudo nixos-rebuild switch --flake .#arcanine-nix && \
      git commit -m "''${1:-Update config}" && \
      git push
    }
  '';

  system.stateVersion = "26.05";
}
