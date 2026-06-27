{ ... }: {
  flake.homeModules.foot = { config, pkgs, ... }: {
    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "Terminus:size=12";
          dpi-aware = "no";
          pad = "10x10";
        };

        colors-dark = {
          background = "000000";
          foreground = "d3d3d3";
          alpha = "0.9";

          regular0 = "1a1a2e";
          regular1 = "8b3a5a";
          regular2 = "4a6fa5";
          regular3 = "7a4f6d";
          regular4 = "3d5a8a";
          regular5 = "9b6b8a";
          regular6 = "6b7fb5";
          regular7 = "c97a8a";

          bright0 = "4a4a6a";
          bright1 = "d4527a";
          bright2 = "7a9fd4";
          bright3 = "e8a0b4";
          bright4 = "8899cc";
          bright5 = "cc88bb";
          bright6 = "aabbdd";
          bright7 = "f0e0e8";
        };

        url = {
          launch = "xdg-open \${url}";
        };
      };
    };
  };
}
