# Shared desktop config (Sway + Wayland stack)
{ config, lib, pkgs, ... }:
{
  programs.sway.enable = true;

  services.displayManager.ly = {
    enable = true;
    settings.session_log = null;
  };

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    git
    tailscale
    unzip
    brightnessctl
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-termfilechooser
    ];
    config.sway = {
      default = lib.mkForce [ "wlr" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
    config.common = {
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  environment.sessionVariables = {
    GTK_USE_PORTAL = "1";
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  security.pam.services.waylock = {};

  hardware.enableRedistributableFirmware = true;
}
