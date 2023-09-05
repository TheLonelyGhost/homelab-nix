{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.torrent;
in {

  imports = [
    # ../qbittorrent.nix
    ../flood.nix
  ];

  options = {
    seedbox = {
      torrent = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Client for downloading torrents.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc ''
            Open the firewall to all ports used by the torrent client.
          '';
        };

        client = lib.mkOption {
          type = lib.types.enum [
            # "aria2"
            "rtorrent"
            # "transmission"
            # "qbittorrent"
          ];
          default = "rtorrent";
          description = lib.mdDoc ''
            Implementation of a torrenting client in which to use.
          '';
        };

        downloadDir = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = lib.mdDoc ''
            Directory where files are downloaded by default.
          '';
        };

        webPort = lib.mkOption {
          type = lib.types.port;
          default = 6800;
          description = lib.mdDoc ''
            HTTP port of the Web UI for the torrenting client.
          '';
        };

        rpcPort = lib.mkOption {
          type = lib.types.port;
          default = 50000;
          description = lib.mdDoc ''
            Port used for RPC communication (rtorrent-only).

            Will not be opened in firewall, even if
            {option}`seedbox.torrent.openFirewall` is enabled.
          '';
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 12345;
          description = lib.mdDoc ''
            Port reported to tracker upon which the client is listening.
          '';
        };
        listenPortDHT = lib.mkOption {
          type = lib.types.port;
          default = 62890;
          description = lib.mdDoc ''
            Port reported in Distributed Hash Table (DHT) upon which the client is listening.
          '';
        };
      };
    };
  };

  config = lib.mkIf (config.seedbox.enable && cfg.enable) (lib.mkMerge [
    # (lib.mkIf (cfg.client == "aria2") {
    #   services.aria2.enable = true;
    # })

    (lib.mkIf (cfg.client == "rtorrent") {
      services.rtorrent = {
        enable = true;
        # package = pkgs.jesec-rtorrent;
        inherit (cfg) openFirewall;

        inherit (cfg) downloadDir;
        port = cfg.listenPort;

        configText = ''
        dht.port.set = ${builtins.toString cfg.listenPortDHT}
        dht.mode.set = auto
        protocol.pex.set = yes

        protocol.encryption.set = require,require_RC4,allow_incoming,try_outgoing

        # scgi_port = localhost:${builtins.toString cfg.rpcPort}
        '';
      };

      services.flood = {
        enable = true;
        port = cfg.webPort;
        # extraArgs = "--rthost=127.0.0.1 --rtport=${builtins.toString cfg.rpcPort}";

        extraArgs = "--rtsocket=${config.services.rtorrent.rpcSocket}";
        user = "rtorrent";
        group = "rtorrent";
      };

      seedbox.consul.services = let
        rtorrent = config.services.rtorrent.package or pkgs.rtorrent;
        flood = config.services.flood.package or pkgs.flood;
      in [
        {
          id = rtorrent.name;
          name = rtorrent.pname or "rtorrent";
          port = cfg.rpcPort;
          meta = {
            inherit (rtorrent) version;
            inherit (rtorrent.meta) description homepage;
          };
          checks = [
            {
              name = "RPC";
              tcp = "localhost:${builtins.toString cfg.rpcPort}";
              interval = "10s";
              timeout = "1s";
            }
          ];
        }
        {
          id = flood.name;
          name = flood.pname or "flood";
          port = cfg.webPort;
          meta = {
            inherit (flood) version;
            inherit (flood.meta) description homepage;
          };
          checks = [
            {
              name = "HTTP";
              http = "http://localhost:${builtins.toString cfg.webPort}/";
              interval = "10s";
              timeout = "3s";
            }
          ];
        }
      ];
    })
    # (lib.mkIf (cfg.client == "qbittorrent") {
    #   services.qbittorrent.enable = true;
    #   services.qbittorrent.openFirewall = cfg.openFirewall;
    # })
    # (lib.mkIf (cfg.client == "transmission") {
    #   services.transmission.enable = true;
    #   services.transmission.openFirewall = cfg.openFirewall;
    # })

    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [
        cfg.webPort
        cfg.listenPort
        cfg.listenPortDHT
      ];
      networking.firewall.allowedUDPPorts = [
        cfg.listenPort
        cfg.listenPortDHT
      ];
    })
  ]);
}
