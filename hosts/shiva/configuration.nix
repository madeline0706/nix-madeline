{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  home-manager.users.madeline.imports = [ ./displays.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Stuff for my Pi 5
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; #to build pi 5 image
  nix.settings.trusted-users = [ "madeline" ];
  nix.settings.extra-platforms = [ "aarch64-linux" ];
  networking.hostName = "shiva";
  nix.settings.extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];
  hardware.cpu.amd.updateMicrocode = true;
  hardware.bluetooth.enable = false;

  programs.steam.enable = true;
  programs.steam.package = pkgs.millennium-steam;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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

  # Let the waybar BAT widget switch TLP profiles without a password prompt.
  security.sudo.extraRules = [{
    users = [ "madeline" ];
    commands = [{
      command = "/run/current-system/sw/bin/tlp";
      options = [ "NOPASSWD" ];
    }];
  }];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "ignore";
  };

  swapDevices = [{ device = "/var/swap"; size = 8192; }];
}
