{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
  ];

  wayland.windowManager.sway = {
    enable = true;
    config = null;
    extraConfig = ''
      # Modifier key [ALT]
      set $mod Mod1
      # Appearance
      default_border pixel 1
      gaps inner 4
      font pango:monospace 10
      # Borders
      client.focused #8b3a5a #8b3a5a  #ffffff #8b3a5a
      # Waybar
      bar {
          swaybar_command waybar
      }
      # Launch app launcher
      bindsym $mod+m exec j4-dmenu-desktop --dmenu="bemenu -l 10 -p run: --fn 'Terminus 12' -c --width-factor 0.3 --nb '#000000ff' --hb '#000000ff' --fb '#000000ff'"
      # Launch terminal
      bindsym $mod+t exec foot
      # Launch Firefox
      bindsym $mod+f exec firefox
      # Kill focused window
      bindsym $mod+q kill
      # Exit sway
      bindsym $mod+Shift+e exit
      # Reload
      bindsym $mod+r reload
      # Lock screen
      bindsym $mod+Escape exec waylock
      # Brightness keys
      bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
      bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
      # Media keys
      bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      # Screenshots / Recordings
      bindsym $mod+z exec grimshot-ss --notify savecopy area
      bindsym $mod+x exec grimshot-rc	
      # Autostart
      exec arrpc
      exec swayidle -w \
          timeout 300 'waylock' \
          timeout 600 'swaymsg "output * dpms off"' \
          resume 'swaymsg "output * dpms on"' \
          before-sleep 'waylock'
      for_window [class=".*"] inhibit_idle fullscreen
      for_window [app_id=".*"] inhibit_idle fullscreen
      exec foot
      # Workspaces — switch
      bindsym $mod+1 workspace number 1
      bindsym $mod+2 workspace number 2
      bindsym $mod+3 workspace number 3
      bindsym $mod+4 workspace number 4
      bindsym $mod+5 workspace number 5
      bindsym $mod+6 workspace number 6
      bindsym $mod+7 workspace number 7
      bindsym $mod+8 workspace number 8
      bindsym $mod+9 workspace number 9
      bindsym $mod+0 workspace number 10
      # Workspaces — move focused window
      bindsym $mod+Shift+1 move container to workspace number 1
      bindsym $mod+Shift+2 move container to workspace number 2
      bindsym $mod+Shift+3 move container to workspace number 3
      bindsym $mod+Shift+4 move container to workspace number 4
      bindsym $mod+Shift+5 move container to workspace number 5
      bindsym $mod+Shift+6 move container to workspace number 6
      bindsym $mod+Shift+7 move container to workspace number 7
      bindsym $mod+Shift+8 move container to workspace number 8
      bindsym $mod+Shift+9 move container to workspace number 9
      bindsym $mod+Shift+0 move container to workspace number 10
    '';
  };
}
