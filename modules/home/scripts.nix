{ config, pkgs, ... }:

let
  grimshot-ss = pkgs.writeScriptBin "grimshot-ss" (builtins.readFile ../../scripts/grimshot-ss.sh);
  grimshot-rc = pkgs.writeScriptBin "grimshot-rc" (builtins.readFile ../../scripts/grimshot-rc.sh);
  nixshot = pkgs.writeScriptBin "nixshot" (builtins.readFile ../../scripts/nixshot.sh);
in
{
  home.packages = with pkgs; [
    grimshot-ss
    grimshot-rc
    nixshot

    grim
    slurp
    jq
    wl-clipboard
    wf-recorder
    awscli2
  ];
}
