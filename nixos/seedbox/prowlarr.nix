
{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.prowlarr;
in {

  options = {
    seedbox = {
      prowlarr = {
        enable = lib.mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc ''
            Torrent index manager for content searchers.
          '';
        };

        openFirewall = lib.mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Prowlarr.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.prowlarr = {
      enable = true;
      inherit (cfg) openFirewall;
    };

    seedbox.consul.services = let
      prowlarr = config.services.prowlarr.package;
      prowlarrPort = 9696;
    in [
      {
        id = prowlarr.name;
        name = prowlarr.pname;
        port = prowlarrPort;
        meta = {
          inherit (prowlarr) version;
          inherit (prowlarr.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString prowlarrPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
