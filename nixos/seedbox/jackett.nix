{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.jackett;
in {

  options = {
    seedbox = {
      jackett = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Torrent index manager for content searchers.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Jackett.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.jackett.enable = true;
    services.jackett.openFirewall = cfg.openFirewall;

    seedbox.consul.services = let
      jackett = config.services.jackett.package;
      jackettPort = 9117;
    in [
      {
        id = jackett.name;
        name = jackett.pname;
        port = jackettPort;
        meta = {
          inherit (jackett) version;
          inherit (jackett.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString jackettPort}/health";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
