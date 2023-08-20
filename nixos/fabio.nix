{ config, lib, pkgs, ... }:

let
  cfg = config.services.fabio;

  fabio = import ../packages/fabio.nix {
    inherit pkgs;
  };

  # TODO: Take `cfg.config` and serialize as a properties file
  # fabioConfigFile = "";
in
{
  imports = [ ];

  options = {
    services.fabio = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
        '';
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = fabio;
        description = ''
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9999;
        description = ''
        '';
      };
      uiPort = lib.mkOption {
        type = lib.types.port;
        default = 9998;
        description = ''
        '';
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
        '';
      };
      # config = lib.mkOption {
      #   type = lib.types.attrset;
      #   default = { };
      #   description = ''
      #   '';
      # };
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      users.users.fabio = {
        inherit (fabio.meta) description;
        group = "fabio";
        isSystemUser = true;
      };
      users.groups.fabio = {};

      security.wrappers.fabio = {
        source = lib.getExe fabio;
        owner = "root";
        group = "root";
        capabilities = "cap_net_bind_service+ep";
      };

      # services.consul = {
      #   extraConfigFiles = [
      #     (builtins.toFile "fabio.json" (builtins.toJSON {
      #       service = {
      #         id = "fabio";
      #         name = "Fabio";
      #         inherit (cfg) port;
      #         meta = {
      #           inherit (fabio.meta) homepage description;
      #           inherit (fabio) version;
      #         };
      #         checks = [
      #           {
      #             id = "tcp";
      #             name = "TCP on port ${builtins.toString cfg.uiPort}";
      #             tcp = "localhost:${builtins.toString cfg.uiPort}";
      #             interval = "10s";
      #             timeout = "1s";
      #           }
      #         ];
      #         tags = [
      #           # Fabio tags:
      #           # "urlprefix-/get"
      #           # "strip=/get"
      #         ];
      #       };
      #     }))
      #   ];
      # };

      systemd.services.fabio = {
        inherit (fabio.meta) description;
        documentation = [fabio.meta.homepage];
        after = [
          "network.target"
          "syslog.target"
        ];
        wantedBy = ["multi-user.target"];

        partOf = lib.optional config.services.consul.enable "consul.service";

        # reloadTriggers = [
        #   cfg.config
        # ];

        # script = "${fabio}/bin/fabio";
        # scriptArgs = lib.optionals (fabioConfig != {}) "-cfg ${fabioConfigFile}";

        serviceConfig = {
          Restart = "always";
          LimitMEMLOCK = "infinity";
          LimitNOFILE = 65535;
          User = "fabio";
          Group = "fabio";

          ExecStart = "${fabio}/bin/fabio -proxy.addr :${builtins.toString cfg.port} -ui.addr :${builtins.toString cfg.uiPort}";

          # Fabio does not mess with `/dev/*`
          PrivateDevices = "yes";
          # Dedicated `/tmp`
          PrivateTmp = "yes";
          # Make `/usr`, `/boot`, and `/etc` read-only
          ProtectSystem = "full";
          # `/home` is not accessible at all
          ProtectHome = "yes";
          NoNewPrivileges = "yes";

          # Allow binding to port < 1024
          AmbientCapabilities = "CAP_NET_BIND_SERVICE";

          # only ipv4, ipv6, unix socket, and netlink networking
          # netlink is necessary so that fabio can list available IPs on startup
          RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
        };
      };
    }

    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [
        cfg.port
        cfg.uiPort
      ];
    })
  ]);
}
