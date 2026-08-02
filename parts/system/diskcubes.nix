{ ... }: {
  # Packages the `diskcubes` disk visualizer — a squarified treemap of the
  # largest files, coloured by category, for spotting what to clean. Applied
  # to every host. Read-only: it never deletes anything.
  flake.nixosModules.diskcubes = { pkgs, ... }:
  let
    diskcubes = pkgs.writeScriptBin "diskcubes" (builtins.readFile ../../scripts/diskcubes.sh);
  in
  {
    environment.systemPackages = [
      diskcubes
      pkgs.gawk       # the treemap/layout engine is written in gawk
      pkgs.findutils  # find with -printf
      pkgs.ncurses    # tput, for terminal size detection
    ];
  };
}
