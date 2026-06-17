# ./claude.nix
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    mcp-nixos
  ];

  xdg.configFile."claude-code/mcp.json".text = builtins.toJSON {
    mcpServers = {
      nixos = {
        command = "mcp-nixos";
      };
    };
  };
}
