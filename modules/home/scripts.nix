{ config, pkgs, ... }:

let
  nixshot = pkgs.writeScriptBin "nixshot" (builtins.readFile ../../scripts/nixshot.sh);
in
{
  home.packages = with pkgs; [
    nixshot

    grim
    slurp
    jq
    wl-clipboard
    wf-recorder
    awscli2
  ];
}
