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
        background-color: rgba(10, 10, 10, 0.75);
        color: #c8c4b0;
      }
      #clock, #pulseaudio, #network, #workspaces, #custom-sysinfo, #battery, #mpris {
        padding: 0 10px;
        color: #c8c4b0;
        background-color: transparent;
      }
      #workspaces button {
        color: #c8c4b0;
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
          format-ethernet = "Et";
          format-wifi = "Wi {signalStrength}%";
          format-disconnected = "Di";
        };
        pulseaudio = {
          format = "Vo {volume}%";
          format-muted = "Mu";
          on-click = "foot -e pulsemixer";
        };
        battery = {
          format = "Ba {capacity}%";
          format-charging = "Ch {capacity}%";
          format-warning = "Wa {capacity}%";
          format-critical = "Cr {capacity}%";
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
