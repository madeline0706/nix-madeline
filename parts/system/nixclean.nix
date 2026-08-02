{ ... }: {
  # Packages the `nixclean` housekeeping script and schedules it to run
  # weekly, pruning generations/store paths older than a week and optimising
  # the store. Applied to every host.
  flake.nixosModules.nixclean = { config, lib, pkgs, ... }:
  let
    nixclean = pkgs.writeScriptBin "nixclean" (builtins.readFile ../../scripts/nixclean.sh);
  in
  {
    # Make `nixclean` available for manual runs.
    environment.systemPackages = [
      nixclean
      pkgs.coreutils # numfmt/df used by the script's reporting
    ];

    # Weekly automatic cleanup. The service runs as root (no sudo re-exec
    # needed), and the timer is persistent so a missed run (machine off)
    # fires on next boot.
    systemd.services.nixclean = {
      description = "Prune old NixOS generations and garbage collect the store";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nixclean}/bin/nixclean --age 7d";
      };
      # switch-to-configuration and nix tooling live here.
      path = [ pkgs.nix pkgs.coreutils ];
    };

    systemd.timers.nixclean = {
      description = "Weekly NixOS cleanup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
