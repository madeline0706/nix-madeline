## Needs work

{ config, pkgs, ... }:

let
  grimshot-ss = pkgs.writeScriptBin "grimshot-ss" (builtins.readFile ./scripts/grimshot-ss.sh);
  grimshot-rc = pkgs.writeScriptBin "grimshot-rc" (builtins.readFile ./scripts/grimshot-rc.sh);
in
{
  home.packages = with pkgs; [
    grimshot-ss
    grimshot-rc

    grim
    slurp
    jq
    wl-clipboard
    wf-recorder
    awscli2
  ];
}
