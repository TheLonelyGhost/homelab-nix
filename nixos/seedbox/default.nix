{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox;
in {
  imports = [
    ./consul.nix

    ./bazarr.nix

    ./ombi.nix
    ./sonarr.nix
    ./radarr.nix
    ./lidarr.nix

    ./jackett.nix
    ./prowlarr.nix

    ./torrenting.nix
  ];

  options = {
    seedbox = {
      enable = lib.mkEnableOption (lib.mdDoc "A torrenting seedbox setup");
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Open ports in the firewall.
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    }
  ]);

  # List packages installed in system profile. To search, run:
  # $ nix search nixpkgs wget
  # environment.systemPackages = [
  #   pkgs.cifs-utils
  # ];

  # List services that you want to enable:
}
