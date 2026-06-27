{ ... }: {
  flake.homeModules.claude = { config, pkgs, ... }: {
    home.packages = with pkgs; [
      claude-code
      mcp-nixos
    ];
  };
}
