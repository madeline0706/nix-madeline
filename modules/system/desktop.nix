# Shared desktop config (Sway + Wayland stack)
{ config, lib, pkgs, ... }:
{
  programs.sway.enable = true;

  services.displayManager.ly.enable = true;

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    waybar
    fastfetch
    git
    arrpc
    lf
    bemenu
    j4-dmenu-desktop
    swayidle
    waylock
    xdg-desktop-portal-termfilechooser
    chafa
    file
    portablemc
    waybar
    fastfetch
    btop
    ncdu
    pulsemixer
    unzip
    tailscale
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

  # Mute Fifine mic's direct monitoring (headphone loopback) before ly starts.
  # The card number can vary, so we find it by name at runtime.
  systemd.services.mute-mic-monitoring = {
    description = "Mute microphone direct monitoring before login";
    wantedBy = [ "ly.service" ];
    before = [ "ly.service" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "mute-mic-monitoring" ''
        card=$(grep -i fifine /proc/asound/cards | awk '{print $1}')
        if [ -n "$card" ]; then
          ${pkgs.alsa-utils}/bin/amixer -c "$card" sset Mic Playback mute || true
        fi
      '';
    };
  };

  security.pam.services.waylock = {};

  hardware.enableRedistributableFirmware = true;
}
