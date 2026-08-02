{ ... }: {
  flake.homeModules.calendar = { config, pkgs, ... }: {
    programs.khal.enable = true;
    programs.vdirsyncer.enable = true;

    # Sync mailbox.org CalDAV -> local every 15 minutes.
    services.vdirsyncer = {
      enable = true;
      frequency = "*:0/15";
    };

    accounts.calendar = {
      basePath = ".local/share/calendars";
      accounts.mailbox = {
        primary = true;
        remote = {
          type = "caldav";
          url = "https://dav.mailbox.org/";
          userName = "jerma985@mailbox.org";
          # App password lives outside the nix store (chmod 600). See CLAUDE.md
          # post-install steps. vdirsyncer reads it via this command.
          passwordCommand = [ "cat" "/home/madeline/.config/vdirsyncer/mailbox-password" ];
        };
        local = {
          type = "filesystem";
          fileExt = ".ics";
        };
        vdirsyncer = {
          enable = true;
          # Discover and pair every calendar present on both sides (Calendar,
          # Birthdays, Tasks) instead of treating the account as one collection.
          collections = [ "from a" "from b" ];
        };
        khal = {
          enable = true;
          type = "discover";
        };
      };
    };
  };
}
