{ config, pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 24;
        modules-left = [ "sway/workspaces" "mpris" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" ];

        clock = {
          format = "{:%Y-%m-%d %I:%M %p}";
          tooltip-format = "<tt>{calendar}</tt>";
        };

        network = {
          format-ethernet = "ETH";
          format-wifi = "WiFi {signalStrength}%";
          format-disconnected = "DISCONNECTED";
        };

        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTED";
          on-click = "foot -e pulsemixer";
        };

        mpris = {
          format = "▶ {artist} — {title}";
          format-paused = "⏸ {artist} — {title}";
        };
      };
    };
  };
}
