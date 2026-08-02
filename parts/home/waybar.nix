{ ... }: {
  flake.homeModules.waybar = { config, pkgs, ... }:
  let
    sysinfo = pkgs.writeShellScript "sysinfo" (builtins.readFile ../../scripts/sysinf.sh);
  in {
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
        #clock, #pulseaudio, #network, #workspaces, #battery, #mpris, #custom-launcher, #custom-tailscale, #custom-help {
          padding: 0 10px;
          color: #c8c4b0;
          background-color: transparent;
        }
        #custom-cpu, #custom-ram, #custom-disk, #custom-net {
          padding: 0 6px;
          color: #c8c4b0;
          background-color: transparent;
        }
        #custom-launcher:hover, #custom-tailscale:hover, #custom-help:hover {
          color: #dbbc7f;
        }
        #workspaces button {
          color: #c8c4b0;
          padding: 0 5px;
          background-color: transparent;
        }
        #workspaces button.focused {
          color: #dbbc7f;
        }
        #battery.warning {
          color: #dbbc7f;
        }
        #battery.critical {
          color: #e67e80;
        }
      '';
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 24;
          modules-left = [ "custom/launcher" "custom/help" "sway/workspaces" "mpris" ];
          modules-center = [ "clock#date" "clock#time" ];
          modules-right = [ "custom/cpu" "custom/ram" "custom/disk" "custom/net" "pulseaudio" "network" "custom/tailscale" "battery" ];
          "clock#date" = {
            format = "{:%Y-%m-%d}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e sh -c 'vdirsyncer sync; ikhal'";
          };
          "clock#time" = {
            format = "{:%I:%M %p}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e tty-clock -c -s";
          };
          network = {
            format-ethernet = "ETH";
            format-wifi = "WIFI {signalStrength}%";
            format-disconnected = "NULL";
            on-click = "foot --app-id=floatterm -e nmtui";
          };
          pulseaudio = {
            format = "VOL {volume}%";
            format-muted = "MUTED";
            on-click = "foot --app-id=floatterm -e pulsemixer";
          };
          battery = {
            format = "BAT {capacity}%";
            format-charging = "CHAR {capacity}%";
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
          "custom/cpu" = {
            exec = "${sysinfo} cpu";
            interval = 1;
            return-type = "";
            format = "{}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e btop";
          };
          "custom/ram" = {
            exec = "${sysinfo} ram";
            interval = 1;
            return-type = "";
            format = "{}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e btop";
          };
          "custom/disk" = {
            exec = "${sysinfo} disk";
            interval = 5;
            return-type = "";
            format = "{}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e sh -c 'diskcubes 512; echo; read -n1 -rs -p \"Press any key to close…\"'";
          };
          "custom/net" = {
            exec = "${sysinfo} net";
            interval = 1;
            return-type = "";
            format = "{}";
            tooltip = false;
            on-click = "foot --app-id=floatterm -e sh -c 'cfspeedtest; echo; read -n1 -rs -p \"Press any key to close…\"'";
          };
          "custom/launcher" = {
            format = "=";
            tooltip = false;
            on-click = "j4-dmenu-desktop --no-generic --dmenu=\"bemenu -l 10 -p run: --fn 'Terminus 12' -c --width-factor 0.3 --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' --tb '#000000ff' --tf '#a7c080ff' --ff '#c8c4b0ff' --hf '#dbbc7fff' -H 20 -B 1 --bdr '#a7c080ff'\"";
          };
          "custom/tailscale" = {
            format = "::";
            tooltip = false;
            on-click = "${pkgs.writeShellScript "tailscale-menu" (builtins.readFile ../../scripts/tailscale-menu.sh)}";
          };
          "custom/help" = {
            format = "?";
            tooltip = false;
            on-click = "${pkgs.writeShellScript "sway-keybinds" (builtins.readFile ../../scripts/sway-keybinds.sh)}";
          };
        };
      };
    };
  };
}
