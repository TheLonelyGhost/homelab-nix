{ config, lib, pkgs, ... }:

let
  # consulLib = pkgs.callPackage ../../lib/consul.nix {};

  cfg = config.seedbox.consul;
in {

  options = {
    seedbox = {
      consul = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Healthchecks and service discovery using HashiCorp Consul
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by Consul.
          '';
        };

        integrateWithSystemDNS = lib.mkEnableOption (lib.mdDoc ''
        Setup system DNS resolver to delegate *.consul DNS resolution
        to the local Consul agent. Currently supports

        - dnsmasq
        '');

        services = lib.mkOption {
          type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
          default = [];
          description = lib.mdDoc ''
            Defines what services aboard machine need to be advertised and monitored.
          '';
          example = let
            pkg = pkgs.ombi;
            port = 5000;
          in [
            {
              id = pkg.name;
              name = pkg.pname;
              inherit port;
              meta = {
                inherit (pkg) version;
                inherit (pkg.meta) description homepage;
              };
              checks = [
                {
                  name = "HTTP";
                  http = "http://localhost:${builtins.toString port}/";
                  interval = "10s";
                  timeout = "5s";
                }
              ];
            }
          ];
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) (lib.mkMerge [
    {
      services.consul = {
        enable = true;

        # Maybe there's some good reason to still disable the UI
        webUi = lib.mkDefault true;

        extraConfig = {
          server = true;
          client_addr = "0.0.0.0";
        };
      };

      environment.etc."consul.d/seedbox.json".text = builtins.toJSON {
        services = cfg.services;
      };
    }

    (lib.mkIf cfg.integrateWithSystemDNS {
      services.dnsmasq.enable = true;
      services.dnsmasq.settings.server = [
        "/consul/127.0.0.1#8600"
      ];
    })

    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [
        8300 # Consul Server
        8301 # LAN serf
        8302 # WAN serf
        8500 # Consul HTTP API
        8600 # DNS
      ];
      networking.firewall.allowedUDPPorts = [
        8301 # LAN serf
        8302 # WAN serf
        8600 # DNS
      ];
    })
  ]);
}
