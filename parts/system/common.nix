{ ... }: {
  flake.nixosModules.common = { config, lib, pkgs, ... }: {
    networking.networkmanager.enable = true;
    time.timeZone = "America/Los_Angeles";
    users.users.madeline = {
      isNormalUser = true;
      extraGroups = [ "wheel" "video" ];
      packages = with pkgs; [
        tree
	git
	speedtest-rs
	android-tools
      ];
    };
    programs.bash.promptInit = ''
      PS1='\[\e[1m\][\u@\h] \w\n> \[\e[0m\]'
    '';
    programs.bash.interactiveShellInit = ''
      nixpush() {
        cd ~/Nix && \
        git add . && \
        git commit -m "''${1:-Update config}" && \
        git push
      }
      nixsync() {
        cd ~/Nix && \
        git pull && \
        sudo nixos-rebuild switch --flake .#$(hostname)
      }
      nixup() {
        cd ~/Nix && \
        git add . && \
        sudo nixos-rebuild switch --flake .#$(hostname) && \
        git commit -m "''${1:-Update config}" && \
        git push
      }
      mc() {
        portablemc start -au madeline0706 "''${1:?Usage: mc <version>}"
      }
    '';
    boot.kernelPackages = pkgs.linuxPackages_cachyos;
    nixpkgs.config.allowUnfree = true;
    programs.firefox.enable = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.warn-dirty = false;
    system.stateVersion = "26.05";
  };
}
