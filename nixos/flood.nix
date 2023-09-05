{ config, lib, pkgs, ... }:

let
  cfg = config.services.flood;
in
{
  options = {
    services = {
      flood = {
        enable = lib.mkEnableOption (lib.mdDoc "Flood web service");

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.flood;
          example = literalExpression "pkgs.flood";
          description = lib.mdDoc ''
            Flood package to use.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "flood";
          description = lib.mdDoc ''
            User account under which Flood runs.
          '';
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "flood";
          description = lib.mdDoc ''
            Group under which Flood runs.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = lib.mdDoc ''
            Port on which to listen for HTTP traffic.
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = lib.mdDoc ''
            Additional arguments to apply to Flood at startup.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enabled (lib.mkMerge [
    {
      systemd.services.flood = {
        after = [ "network.target" ];
        description = pkgs.flood.meta.description;
        wantedBy = [ "multi-user.target" ];
        path = [ cfg.package ];

        serviceConfig = {
          ExecStart = "${lib.getExe cfg.package} ${cfg.extraArgs} --port=${builtins.toString cfg.port}";
          Restart = "on-failure";
          RestartSec = "3";
          KillMode = "process";
          User = cfg.user;
          Group = cfg.group;
        };
      };

      environment.systemPackages = [
        cfg.package
      ];

      users.users = lib.mkIf (cfg.user == "flood") {
        flood = {
          inherit (cfg.package.meta) description;
          isSystemUser = true;

          group = cfg.group;
        };
      };

      users.groups = lib.mkIf (cfg.group == "flood") {
        flood = {};
      };
    }

    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [
        cfg.port
      ];
    })
  ]);
}
