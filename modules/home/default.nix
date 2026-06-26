{ config, pkgs, lib, ... }:
let
  mprisSrc = pkgs.fetchFromGitHub {
    owner = "lazykern";
    repo = "mprisence";
    rev = "v1.7.0";
    hash = "sha256-Ss6RXxtpSI3jfq5CAwRLE0XA3tFkIBI+JMyUov2DSpM=";
  };
  mprisence = pkgs.mprisence.overrideAttrs (old: {
    version = "1.7.0";
    src = mprisSrc;
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit (old) pname;
      version = "1.7.0";
      src = mprisSrc;
      hash = "sha256-AKj+DibLyoWUw+082m5wMVnZAY4Kmf3+daRJDGeLKtc=";
    };
  });
in
{
  home.stateVersion = "26.05";

  home.file."wallpapers/.keep".text = "";

  systemd.user.services.mprisence = {
    Unit.Description = "Discord Rich Presence for MPRIS media players";
    Service = {
      Type = "simple";
      ExecStart = "${mprisence}/bin/mprisence";
      Restart = "always";
      RestartSec = 10;
      Environment = [ "RUST_LOG=info" "RUST_BACKTRACE=1" ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.packages = with pkgs; [
    terminus_font
    playerctl
    libnotify
    arrpc
    lf
    bemenu
    j4-dmenu-desktop
    swayidle
    waylock
    xdg-desktop-portal-termfilechooser
    chafa
    file
    portablemc
    waybar
    fastfetch
    btop
    ncdu
    pulsemixer
    mprisence
  ];

  xdg.configFile."mprisence/config.toml".text = ''
    [web_player.navidrome]
    match_pattern = "navi.spellbound.sh"
    ignore = false
    name = "Navidrome"
  '';

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${config.home.homeDirectory}/.config/xdg-desktop-portal-termfilechooser/lf-wrapper.sh
  '';

  xdg.configFile."xdg-desktop-portal-termfilechooser/lf-wrapper.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      multiple="$1"
      directory="$2"
      save="$3"
      path="$4"
      out="$5"
      foot --app-id=filechooser -- sh -c 'LF_CHOOSER_FILE="$1" LF_CHOOSER_DIRECTORY="$2" lf "$3"' -- "$out" "$directory" "$path"
    '';
  };

  xdg.configFile."lf/lfrc".text = ''
    set previewer ~/.config/lf/previewer
    set sixel true
    cmd open &{{
      if [ -n "$LF_CHOOSER_FILE" ]; then
        echo "$f" > "$LF_CHOOSER_FILE"
        lf -remote "send $id quit"
      else
        xdg-open "$f"
      fi
    }}
    cmd choose-dir &{{
      if [ -n "$LF_CHOOSER_FILE" ] && [ -d "$f" ]; then
        echo "$f" > "$LF_CHOOSER_FILE"
        lf -remote "send $id quit"
      elif [ -d "$f" ]; then
        lf -remote "send $id cd \"$f\""
      else
        lf -remote "send $id open"
      fi
    }}
    map <enter> choose-dir
  '';

  xdg.configFile."lf/previewer" = {
    executable = true;
    text = ''
      #!/bin/sh
      case "$(file -Lb --mime-type -- "$1")" in
        image/*) chafa -f sixel -s "$2x$3" --animate off --polite on -t 1 --bg black "$1" ;;
        text/*) cat "$1" ;;
      esac
    '';
  };


  imports = [
    ./sway.nix
    ./waybar.nix
    ./foot.nix
    ./mako.nix
    ./scripts.nix
    ./claude.nix
  ];
}
