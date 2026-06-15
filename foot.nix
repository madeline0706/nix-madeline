{ config, pkgs, ... }:
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Terminus:size=120";
        dpi-aware = "no";
        pad = "10x10";
      };

      colors-dark = {
        background = "000000";
        foreground = "d3d3d3";
        alpha = "0.9";

        regular0 = "1a1a2e"; # black > deep navy
        regular1 = "8b3a5a"; # red > dark rose
        regular2 = "4a6fa5"; # green > slate blue
        regular3 = "7a4f6d"; # brown/yellow > dusty mauve
        regular4 = "3d5a8a"; # blue > periwinkle
        regular5 = "9b6b8a"; # magenta > muted violet-pink
        regular6 = "6b7fb5"; # cyan > cool blue-lavender
        regular7 = "c97a8a"; # red orange > warm coral rose

        bright0 = "4a4a6a"; # bright black > medium slate
        bright1 = "d4527a"; # bright red > bright rose
        bright2 = "7a9fd4"; # bright green > bright periwinkle
        bright3 = "e8a0b4"; # bright yellow > soft pink
        bright4 = "8899cc"; # bright blue > lavender blue
        bright5 = "cc88bb"; # bright magenta > bright dusty violet
        bright6 = "aabbdd"; # bright cyan > pale blue lavender
        bright7 = "f0e0e8"; # bright white > near-white with pink tint
      };

      url = {
        launch = "xdg-open \${url}";
      };
    };
  };
}
