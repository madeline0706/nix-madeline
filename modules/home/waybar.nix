{ config, pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: "Terminus";
        font-size: 16px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }
      window#waybar {
        background-color: #0a0a0a;
        color: #fff8e1;
      }
      #clock, #pulseaudio, #network, #workspaces, #custom-sysinfo, #battery, #mpris {
        padding: 0 10px;
        color: #fff8e1;
        background-color: #0a0a0a;
      }
      #workspaces button {
        color: #fff8e1;
        padding: 0 5px;
        background-color: transparent;
      }
      #workspaces button.focused {
        color: #ffea00;
      }
      #battery.warning {
        color: #ffea00;
      }
      #battery.critical {
        color: #e6001a;
        font-weight: bold;
      }
    '';
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 24;
        modules-left = [ "sway/workspaces" "mpris" ];
        modules-center = [ "clock" ];
        modules-right = [ "custom/sysinfo" "pulseaudio" "network" "battery" ];
        clock = {
          format = "{:%Y-%m-%d %I:%M %p}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
        network = {
          format-ethernet = "ETHR";
          format-wifi = "WIFI {signalStrength}%";
          format-disconnected = "DISCONNECTED";
        };
        pulseaudio = {
          format = "VLME {volume}%";
          format-muted = "MUTED";
          on-click = "foot -e pulsemixer";
        };
        battery = {
          format = "BATR {capacity}%";
          format-charging = "CHRG {capacity}%";
          format-warning = "WARN {capacity}%";
          format-critical = "CRIT {capacity}%";
          states = {
            warning = 30;
            critical = 15;
          };
        };
        mpris = {
          format = "> {artist} — {title}";
          format-paused = "= {artist} — {title}";
        };
        "custom/sysinfo" = {
          exec = "${pkgs.writeShellScript "sysinfo" (builtins.readFile ../../scripts/sysinf.sh)}";
          interval = 1;
          return-type = "";
          format = "{}";
        };
      };
    };
  };
}
