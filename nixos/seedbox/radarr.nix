{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.radarr;
in {

  options = {
    seedbox = {
      radarr = {
        enable = lib.mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Media content searcher for cinema.
          '';
        };

        openFirewall = lib.mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Radarr.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.radarr = {
      enable = true;
      inherit (cfg) openFirewall;
    };

    seedbox.consul.services = let
      radarr = config.services.radarr.package;
      radarrPort = 7878;
    in [
      {
        id = radarr.name;
        name = radarr.pname;
        port = radarrPort;
        meta = {
          inherit (radarr) version;
          inherit (radarr.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString radarrPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
