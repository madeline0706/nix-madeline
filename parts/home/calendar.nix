{ ... }: {
  flake.homeModules.calendar = { config, pkgs, ... }: {
    programs.khal.enable = true;
    programs.vdirsyncer.enable = true;

    # Sync the master calendar every 15 minutes.
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
          # Point directly at the single mailbox.org "Calendar" collection
          # (its opaque CalDAV id) instead of discovering Tasks/Birthdays too.
          url = "https://dav.mailbox.org/caldav/Y2FsOi8vMC8zMg/";
          userName = "jerma985@mailbox.org";
          # App password lives outside the nix store (chmod 600). See CLAUDE.md.
          passwordCommand = [ "cat" "/home/madeline/.config/vdirsyncer/mailbox-password" ];
        };
        local = {
          type = "filesystem";
          fileExt = ".ics";
        };
        vdirsyncer.enable = true;
        khal.enable = true;
      };
    };
  };
}
