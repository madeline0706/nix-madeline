{ ... }: {
  flake.homeModules.waybar = { config, pkgs, ... }: {
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
        #clock, #pulseaudio, #network, #workspaces, #custom-sysinfo, #battery, #mpris, #custom-launcher, #custom-tailscale, #custom-help {
          padding: 0 10px;
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
          modules-center = [ "clock" ];
          modules-right = [ "custom/sysinfo" "pulseaudio" "network" "custom/tailscale" "battery" ];
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
          "custom/launcher" = {
            format = "=";
            tooltip = false;
            on-click = "j4-dmenu-desktop --no-generic --dmenu=\"bemenu -l 10 -p run: --fn 'Terminus 12' -c --width-factor 0.3 --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' --hf '#dbbc7fff' -H 24 -B 1 --bdr '#a7c080ff'\"";
          };
          "custom/tailscale" = {
            format = "TS";
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
