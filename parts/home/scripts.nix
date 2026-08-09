{ ... }: {
  flake.homeModules.scripts = { config, pkgs, ... }:
  let
    nixshot = pkgs.writeScriptBin "nixshot" (builtins.readFile ../../scripts/nixshot.sh);
    post = pkgs.writeScriptBin "post" (builtins.readFile ../../scripts/post.sh);
  in
  {
    home.packages = with pkgs; [
      nixshot
      post

      grim
      slurp
      jq
      wl-clipboard
      wf-recorder
      awscli2
    ];
  };
}
