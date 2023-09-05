{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.sonarr;
in {

  options = {
    seedbox = {
      sonarr = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Media content searcher for TV and Anime.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Sonarr.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.sonarr = {
      enable = true;
      inherit (cfg) openFirewall;
    };

    seedbox.consul.services = let
      sonarr = config.services.sonarr.package or pkgs.sonarr;
      sonarrPort = 8989;
    in [
      {
        id = sonarr.name;
        name = sonarr.pname;
        port = sonarrPort;
        meta = {
          inherit (sonarr) version;
          inherit (sonarr.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString sonarrPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
