{ ... }: {
  flake.nixosModules.common = { config, lib, pkgs, ... }: {
    networking.networkmanager.enable = true;
    time.timeZone = "America/Los_Angeles";
    users.users.madeline = {
      isNormalUser = true;
      extraGroups = [ "wheel" "video" "networkmanager" ];
      packages = with pkgs; [
        tree
	git
	cfspeedtest
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
        local version channel='Release'
        [ "$1" = "--snapshots" ] && channel='Release|Snapshot'
        version=$(portablemc search 2>/dev/null \
          | awk -F'│' -v ch="$channel" 'NF>3 && $3 ~ ch {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}' \
          | bemenu -l 20 -p "minecraft" --fn 'Terminus 12' -c --width-factor 0.3 \
              --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' \
              --tb '#000000ff' --tf '#a7c080ff' --ff '#c8c4b0ff' --hf '#dbbc7fff' \
              -H 20 -B 1 --bdr '#a7c080ff') || return
        [ -n "$version" ] && portablemc start -au madeline0706 "$version"
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
