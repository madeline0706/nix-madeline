{ ... }: {
  flake.homeModules.foot = { config, pkgs, lib, ... }:
  let
    # Each theme is a foot [colors-dark] section, swapped in on sway reload.
    mkTheme = name: body: pkgs.writeText "foot-${name}.ini" ''
      [colors-dark]
      ${body}
    '';

    themes = {
      spellbound = mkTheme "spellbound" ''
        alpha=0.9
        foreground=d3d3d3
        background=000000
        regular0=1a1a2e
        regular1=8b3a5a
        regular2=4a6fa5
        regular3=7a4f6d
        regular4=3d5a8a
        regular5=9b6b8a
        regular6=6b7fb5
        regular7=c97a8a
        bright0=4a4a6a
        bright1=d4527a
        bright2=7a9fd4
        bright3=e8a0b4
        bright4=8899cc
        bright5=cc88bb
        bright6=aabbdd
        bright7=f0e0e8
      '';

      tidal = mkTheme "tidal" ''
        alpha=0.9
        foreground=cfe6ec
        background=031f2b
        regular0=0a2a38
        regular1=e2685a
        regular2=3fb8a6
        regular3=d7b56a
        regular4=3f9fd4
        regular5=6f8fcf
        regular6=4fc6d8
        regular7=a9ccd6
        bright0=1a4453
        bright1=ff8578
        bright2=63d8c6
        bright3=f0d488
        bright4=63b8ec
        bright5=8fa8e6
        bright6=74e0f0
        bright7=e6f2f6
      '';

      inferno = mkTheme "inferno" ''
        alpha=0.92
        foreground=f5d8b8
        background=160806
        regular0=2a1410
        regular1=ff4a2a
        regular2=e08a2a
        regular3=ffb838
        regular4=d4562a
        regular5=e0662a
        regular6=f0894f
        regular7=f0c8a0
        bright0=4a241a
        bright1=ff6a4a
        bright2=ffa84a
        bright3=ffd05a
        bright4=ff7a4a
        bright5=ff8a4a
        bright6=ffab6a
        bright7=ffe6cc
      '';

      air = mkTheme "air" ''
        alpha=0.9
        foreground=cdd9e0
        background=0c1418
        regular0=1c2a30
        regular1=c56b66
        regular2=6fae86
        regular3=c2a25f
        regular4=5f9cc8
        regular5=9a83b8
        regular6=5fb3c0
        regular7=b7c6ce
        bright0=32424a
        bright1=e08a84
        bright2=8fcfa4
        bright3=e0c07f
        bright4=7fbce8
        bright5=b7a3d8
        bright6=7fd3e0
        bright7=e6f0f4
      '';

      leaf = mkTheme "leaf" ''
        alpha=0.9
        foreground=d2e2ca
        background=0a1a0e
        regular0=16281a
        regular1=c85f4d
        regular2=6bb24c
        regular3=b3a94f
        regular4=4f9a7c
        regular5=8aa75f
        regular6=5cb89a
        regular7=b9ccb1
        bright0=27402c
        bright1=e07a66
        bright2=8ad066
        bright3=d0c56a
        bright4=6cb896
        bright5=a6c47a
        bright6=78d4b4
        bright7=dcecd4
      '';
    };

    themesDir = pkgs.runCommand "foot-themes" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n"
        (lib.mapAttrsToList (name: file: "cp ${file} $out/${name}.ini") themes)}
    '';

    # `theme`        -> list available themes
    # `theme <name>` -> switch to <name>: write it for future foot windows and
    #                   recolor the current terminal live via OSC escapes.
    theme = pkgs.writeShellScriptBin "theme" ''
      themes_dir=${themesDir}

      list() {
        echo "Available themes:"
        for f in "$themes_dir"/*.ini; do
          printf '  %s\n' "$(basename "$f" .ini)"
        done
      }

      if [ $# -eq 0 ]; then
        list
        exit 0
      fi

      src="$themes_dir/$1.ini"
      if [ ! -f "$src" ]; then
        echo "Unknown theme: $1" >&2
        list >&2
        exit 1
      fi

      mkdir -p "$HOME/.config/foot"
      cp -f "$src" "$HOME/.config/foot/theme.ini"

      # Recolor the terminal this command is running in.
      if [ -t 1 ]; then
        while IFS='=' read -r key val; do
          case "$key" in
            regular[0-7]) printf '\033]4;%d;#%s\033\\' "''${key#regular}" "$val" ;;
            bright[0-7])  printf '\033]4;%d;#%s\033\\' "$(( ''${key#bright} + 8 ))" "$val" ;;
            foreground)   printf '\033]10;#%s\033\\' "$val" ;;
            background)   printf '\033]11;#%s\033\\' "$val" ;;
          esac
        done < "$src"
      fi

      echo "Theme set to $1 (new foot windows use it; other open windows unchanged)"
    '';

    # Picks a random theme on sway reload. foot can't reload its config from
    # disk, so only foot windows opened after this runs pick up the new theme.
    random-foot-theme = pkgs.writeShellScriptBin "random-foot-theme" ''
      pick=$(find ${themesDir} -name '*.ini' | shuf -n 1)
      mkdir -p "$HOME/.config/foot"
      cp -f "$pick" "$HOME/.config/foot/theme.ini"
    '';
  in
  {
    programs.foot.enable = true;

    home.packages = [ theme random-foot-theme ];

    # Own the config directly (instead of programs.foot.settings) so we can put
    # the top-level `include` before any section.
    xdg.configFile."foot/foot.ini".text = ''
      include=~/.config/foot/theme.ini

      [main]
      font=Terminus:size=12
      dpi-aware=no
      pad=10x10

      [url]
      launch=xdg-open ''${url}
    '';

    # Make sure theme.ini exists before foot ever runs, so the include never
    # points at a missing file.
    home.activation.footTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${random-foot-theme}/bin/random-foot-theme
    '';
  };
}
