{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.ombi;
in {

  options = {
    seedbox = {
      ombi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Media request engine for Plex.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Ombi.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.ombi = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    seedbox.consul.services = let
      ombi = config.services.ombi.package or pkgs.ombi;
      ombiPort = 5000;
    in [
      {
        id = ombi.name;
        name = ombi.pname;
        port = ombiPort;
        meta = {
          inherit (ombi) version;
          inherit (ombi.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString ombiPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
