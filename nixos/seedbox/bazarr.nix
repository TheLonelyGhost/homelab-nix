{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.bazarr;
in {

  options = {
    seedbox = {
      bazarr = {
        enable = lib.mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Subtitle searcher for media.
          '';
        };

        openFirewall = lib.mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Bazarr.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) {
    services.bazarr = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    seedbox.consul.services = let
      bazarr = config.services.bazarr.package;
      bazarrPort = 6767;
    in [
      {
        id = bazarr.name;
        name = bazarr.pname;
        port = bazarrPort;
        meta = {
          inherit (bazarr) version;
          inherit (bazarr.meta) description homepage;
        };
        checks = [
          {
            name = "HTTP";
            http = "http://localhost:${builtins.toString bazarrPort}/";
            interval = "10s";
            timeout = "3s";
          }
        ];
      }
    ];
  };
}
