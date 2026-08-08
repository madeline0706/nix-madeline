{ ... }: {
  # Send a red (urgency=critical, styled in parts/home/mako.nix) notification
  # when the battery — while discharging — drops to 15%, 10% and 5%. A user
  # timer polls every minute; a small state file makes each threshold notify
  # exactly once per discharge, and charging/rising above 15% re-arms them.
  flake.homeModules.battery-notify = { config, pkgs, ... }:
  let
    battery-check = pkgs.writeShellScript "battery-notify-check" ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/battery-notify.last"

      for bat in /sys/class/power_supply/BAT*; do
        [ -r "$bat/capacity" ] && [ -r "$bat/status" ] || continue
        cap=$(cat "$bat/capacity")
        status=$(cat "$bat/status")

        # Charging or above 15% → nothing to warn about; re-arm the thresholds.
        if [ "$status" != "Discharging" ] || [ "$cap" -gt 15 ]; then
          rm -f "$state"
          exit 0
        fi

        if   [ "$cap" -le 5 ];  then bucket=5
        elif [ "$cap" -le 10 ]; then bucket=10
        else                         bucket=15
        fi

        # Only notify when the threshold bucket changes (edge-triggered).
        last=$(cat "$state" 2>/dev/null || echo 0)
        if [ "$bucket" != "$last" ]; then
          ${pkgs.libnotify}/bin/notify-send \
            -a battery -u critical \
            -h string:x-canonical-private-synchronous:battery \
            "Low battery" "Battery at ''${cap}% — plug in a charger."
          echo "$bucket" > "$state"
        fi
        exit 0
      done
    '';
  in
  {
    systemd.user.services.battery-notify = {
      Unit = {
        Description = "Notify on low battery thresholds";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${battery-check}";
      };
    };

    systemd.user.timers.battery-notify = {
      Unit.Description = "Poll battery for low-battery notifications";
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
