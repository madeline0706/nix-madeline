{ ... }: {
  # Every time the battery drops below 15% (while discharging), flash a
  # manga-style "impact frame" across the screen. A polling user timer checks
  # the battery every few minutes and, while low, keeps flashing until charging.
  flake.homeModules.impact-frame = { config, pkgs, ... }:
  let
    impact-frame = pkgs.writeScriptBin "impact-frame" (builtins.readFile ../../scripts/impact-frame.sh);

    # Fire the frame only when a battery is present, discharging and under 15%.
    battery-check = pkgs.writeShellScript "impact-frame-battery-check" ''
      for bat in /sys/class/power_supply/BAT*; do
        [ -r "$bat/capacity" ] && [ -r "$bat/status" ] || continue
        cap=$(cat "$bat/capacity")
        status=$(cat "$bat/status")
        if [ "$status" = "Discharging" ] && [ "$cap" -lt 15 ]; then
          exec ${impact-frame}/bin/impact-frame
        fi
      done
    '';
  in
  {
    home.packages = with pkgs; [
      impact-frame
      imagemagick
      imv
    ];

    systemd.user.services.impact-frame = {
      Unit = {
        Description = "Flash a low-battery impact frame";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${battery-check}";
      };
    };

    systemd.user.timers.impact-frame = {
      Unit.Description = "Poll battery to flash a low-battery impact frame";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "3min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
