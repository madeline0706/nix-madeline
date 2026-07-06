{ ... }: {
  flake.homeModules.sway = { config, pkgs, ... }:
  let
    random-wallpaper = pkgs.writeShellScriptBin "random-wallpaper" ''
      pkill swaybg || true
      wallpaper=$(find "$HOME/wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | shuf -n 1)
      [ -n "$wallpaper" ] && ${pkgs.swaybg}/bin/swaybg -i "$wallpaper" -m fill &
    '';
    idle-daemon = pkgs.writeShellScriptBin "idle-daemon" ''
      pkill swayidle || true
      exec ${pkgs.swayidle}/bin/swayidle -w \
        timeout 300 'waylock -fork-on-lock' \
        timeout 310 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        timeout 900 'if pgrep -x waylock >/dev/null; then systemctl suspend; fi' \
        before-sleep 'waylock -fork-on-lock'
    '';
  in
  {
    home.packages = with pkgs; [
      random-wallpaper
    ];

    wayland.windowManager.sway = {
      enable = true;
      config = {
        modifier = "Mod4";

        fonts = {
          names = [ "monospace" ];
          size = 10.0;
        };

        gaps = {
          inner = 4;
        };

        window = {
          border = 1;
          titlebar = false;
        };

        colors.focused = {
          border = "#8b3a5a";
          background = "#8b3a5a";
          text = "#ffffff";
          indicator = "#8b3a5a";
          childBorder = "#8b3a5a";
        };

        bars = [
          { command = "waybar"; }
        ];

        input = {
          "type:touchpad" = {
            dwt = "disabled";
          };
        };

        keybindings = let mod = "Mod4"; in {
          # App launcher
          "${mod}+m" = "exec j4-dmenu-desktop --no-generic --dmenu=\"bemenu -l 10 -p run: --fn 'Terminus 12' -c --width-factor 0.3 --nb '#000000ff' --hb '#000000ff' --fb '#000000ff'\"";
          # Terminal
          "${mod}+t" = "exec foot";
          # Firefox
          "${mod}+f" = "exec firefox";
          # Kill
          "${mod}+q" = "kill";
          # Exit sway
          "${mod}+Shift+p" = "exit";
          # Reload
          "${mod}+r" = "reload";
          # Lock screen
          "${mod}+Escape" = "exec waylock";
          "${mod}+l" = "exec waylock";
          # Brightness
          "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
          # Media
          "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          # Screenshots
          "${mod}+z" = "exec nixshot ss --notify savecopy area";
          "${mod}+x" = "exec nixshot rc";
          # Navigation
          "${mod}+left" = "focus left";
          "${mod}+down" = "focus down";
          "${mod}+up" = "focus up";
          "${mod}+right" = "focus right";
          "${mod}+h" = "splith";
          "${mod}+v" = "splitv";
          "${mod}+e" = "fullscreen";
          "${mod}+Shift+f" = "floating toggle";
          # Workspaces — switch
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";
          "${mod}+0" = "workspace number 10";
          # Workspaces — move
          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";
          "${mod}+Shift+0" = "move container to workspace number 10";
        };

        startup = [
          { command = "swaymsg workspace number 1"; }
          { command = "${random-wallpaper}/bin/random-wallpaper"; always = true; }
          { command = "rm ~/ly-session.log"; }
          { command = "arrpc"; }
          { command = "${idle-daemon}/bin/idle-daemon"; always = true; }
        ];

        window.commands = [
          { criteria = { class = ".*"; }; command = "inhibit_idle fullscreen"; }
          { criteria = { app_id = ".*"; }; command = "inhibit_idle fullscreen"; }
        ];
      };
    };
  };
}
