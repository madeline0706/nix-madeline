{ ... }: {
  flake.homeModules.immich = { config, pkgs, lib, ... }:
  let
    # Credentials live in an untracked file (like nixshot's R2 env), e.g.:
    #   IMMICH_INSTANCE_URL=https://immich.example.com/api
    #   IMMICH_API_KEY=<api key from Immich > Account Settings > API Keys>
    envFile = "${config.xdg.configHome}/immich/env";

    immich-sync = pkgs.writeShellScriptBin "immich-sync" ''
      set -euo pipefail

      ENV_FILE="${envFile}"
      if [ ! -f "$ENV_FILE" ]; then
        echo "immich-sync: no credentials at $ENV_FILE — skipping" >&2
        exit 0
      fi
      set -a
      . "$ENV_FILE"
      set +a

      if [ -z "''${IMMICH_INSTANCE_URL:-}" ] || [ -z "''${IMMICH_API_KEY:-}" ]; then
        echo "immich-sync: IMMICH_INSTANCE_URL / IMMICH_API_KEY missing in $ENV_FILE" >&2
        exit 1
      fi

      immich="${pkgs.immich-cli}/bin/immich"

      sync_dir() {
        local dir="$1" album="$2"
        if [ ! -d "$dir" ]; then
          echo "immich-sync: $dir does not exist, skipping"
          return 0
        fi
        echo "immich-sync: uploading $dir -> album '$album'"
        # Idempotent: the server dedupes by checksum, so re-runs skip existing assets.
        "$immich" upload --recursive --album-name "$album" "$dir"
      }

      sync_dir "$HOME/Screenshots" "Screenshots"
      sync_dir "$HOME/wallpapers"  "Wallpapers"
    '';
  in
  {
    home.packages = [ pkgs.immich-cli immich-sync ];

    systemd.user.services.immich-sync = {
      Unit.Description = "Sync Screenshots and wallpapers to Immich";
      Service = {
        Type = "oneshot";
        ExecStart = "${immich-sync}/bin/immich-sync";
      };
    };

    systemd.user.timers.immich-sync = {
      Unit.Description = "Hourly Immich sync of Screenshots and wallpapers";
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
