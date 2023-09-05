{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.lidarr;
in {

  options = {
    seedbox = {
      lidarr = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Media content searcher for music.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Lidarr.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.lidarr = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    seedbox.consul.services = let
      lidarr = config.services.lidarr.package or pkgs.lidarr;
      lidarrPort = 8686;
    in [
      {
        id = lidarr.name;
        name = lidarr.pname;
        port = lidarrPort;
        meta = {
          inherit (lidarr) version;
          inherit (lidarr.meta) description homepage;
        };
        checks = [
          {
            name = "RPC";
            http = "http://localhost:${builtins.toString lidarrPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
