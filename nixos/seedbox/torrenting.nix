{ config, lib, pkgs, ... }:

let
  cfg = config.seedbox.torrent;

  defaultRtorrentConfig = builtins.readFile ../../files/rtorrent.rc;
  rtorrentConfig = {configDir ? "/config/", downloadsDir ? "/downloads/"}: pkgs.writeText "rtorrent.rc" ''
    #############################################################################
    # A minimal rTorrent configuration that provides the basic features
    # you want to have in addition to the built-in defaults.
    #
    # See https://github.com/rakshasa/rtorrent/wiki/CONFIG-Template
    # for an up-to-date version.
    #############################################################################


    ## Instance layout (base paths)
    method.insert = cfg.basedir,  private|const|string, (cat,"${configDir}")
    method.insert = cfg.download, private|const|string, (cat,"${downloadsDir}")
    method.insert = cfg.logs,     private|const|string, (cat,(cfg.basedir),"log/")
    method.insert = cfg.logfile,  private|const|string, (cat,(cfg.logs),"rtorrent-",(system.time),".log")
    method.insert = cfg.session,  private|const|string, (cat,(cfg.basedir),"session/")
    method.insert = cfg.watch,    private|const|string, (cat,(cfg.basedir),"watch/")


    ## Create instance directories
    execute.throw = sh, -c, (cat,\
        "mkdir -p \"",(cfg.logs),"\" ",\
        "\"",(cfg.session),"\" ",\
        "\"",(cfg.watch),"/load\" ",\
        "\"",(cfg.watch),"/start\" ")


    ## Listening port for incoming peer traffic (fixed; you can also randomize it)
    ${if (cfg.listenPort > 0) then ''
    network.port_range.set = ${builtins.toString cfg.listenPort}-${builtins.toString cfg.listenPort}
    network.port_random.set = no
    '' else ''
    network.port_random.set = yes
    ''}


    ## Tracker-less torrent and UDP tracker support
    ## (conservative settings for 'private' trackers, change for 'public')
    ${if (cfg.listenPortDHT > 0) then ''
    dht.port.set = ${builtins.toString cfg.listenPortDHT}
    dht.mode.set = auto
    protocol.pex.set = yes
    '' else ''
    dht.mode.set = disable
    protocol.pex.set = no
    ''}

    trackers.use_udp.set = yes


    ## Peer settings
    throttle.max_uploads.set = 100
    throttle.max_uploads.global.set = 250

    throttle.min_peers.normal.set = 20
    throttle.max_peers.normal.set = 60
    throttle.min_peers.seed.set = 30
    throttle.max_peers.seed.set = 80
    trackers.numwant.set = 80

    protocol.encryption.set = require,require_RC4,allow_incoming,try_outgoing

    ## Limits for file handle resources, this is optimized for
    ## an `ulimit` of 1024 (a common default). You MUST leave
    ## a ceiling of handles reserved for rTorrent's internal needs!
    network.http.max_open.set = 50
    network.max_open_files.set = 600
    network.max_open_sockets.set = 300


    ## Memory resource usage (increase if you have a large number of items loaded,
    ## and/or the available resources to spend)
    pieces.memory.max.set = 1800M
    network.xmlrpc.size_limit.set = 4M


    ## Basic operational settings (no need to change these)
    session.path.set = (cat, (cfg.session))
    directory.default.set = (cat, (cfg.download))
    log.execute = (cat, (cfg.logs), "execute.log")
    #log.xmlrpc = (cat, (cfg.logs), "xmlrpc.log")
    execute.nothrow = sh, -c, (cat, "echo >",\
        (session.path), "rtorrent.pid", " ",(system.pid))


    ## Other operational settings (check & adapt)
    encoding.add = utf8
    system.umask.set = 0027
    system.cwd.set = (directory.default)
    network.http.dns_cache_timeout.set = 25
    schedule2 = monitor_diskspace, 15, 60, ((close_low_diskspace, 1000M))
    #pieces.hash.on_completion.set = no
    #view.sort_current = seeding, greater=d.ratio=
    #keys.layout.set = qwerty
    #network.http.capath.set = "/etc/ssl/certs"
    #network.http.ssl_verify_peer.set = 0
    #network.http.ssl_verify_host.set = 0


    ## Some additional values and commands
    method.insert = system.startup_time, value|const, (system.time)
    method.insert = d.data_path, simple,\
        "if=(d.is_multi_file),\
            (cat, (d.directory), /),\
            (cat, (d.directory), /, (d.name))"
    method.insert = d.session_file, simple, "cat=(session.path), (d.hash), .torrent"


    ## Watch directories (add more as you like, but use unique schedule names)
    ## Add torrent
    schedule2 = watch_load, 11, 10, ((load.verbose, (cat, (cfg.watch), "load/*.torrent")))
    ## Add & download straight away
    schedule2 = watch_start, 10, 10, ((load.start_verbose, (cat, (cfg.watch), "start/*.torrent")))


    ## Run the rTorrent process as a daemon in the background
    ## (and control via XMLRPC sockets)
    #system.daemon.set = true
    #network.scgi.open_local = (cat,(session.path),rpc.socket)
    #execute.nothrow = chmod,770,(cat,(session.path),rpc.socket)


    ## Logging:
    ##   Levels = critical error warn notice info debug
    ##   Groups = connection_* dht_* peer_* rpc_* storage_* thread_* tracker_* torrent_*
    print = (cat, "Logging to ", (cfg.logfile))
    log.open_file = "log", (cfg.logfile)
    log.add_output = "info", "log"
    #log.add_output = "tracker_debug", "log"

    ### END of rtorrent.rc ###
  '';

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

        wireguardConfigFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = lib.mdDoc ''
            Wireguard configuration file which will be used solely by the torrenting software.
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
      # virtualisation.oci-containers.backend = "docker";
      virtualisation.oci-containers.containers.torrent = {
        image = "ghcr.io/hotio/rflood:latest";
        environment = {
          PUID = "1000";
          PGID = "1000";
          UMASK = "002";
          TZ = "Etc/UTC";
          WEBUI_PORTS = "${builtins.toString cfg.webPort}/tcp,${builtins.toString cfg.webPort}/udp";
          VPN_ADDITIONAL_PORTS = "${builtins.toString cfg.listenPort}/tcp,${builtins.toString cfg.listenPort}/udp,${builtins.toString cfg.listenPortDHT}/tcp,${builtins.toString cfg.listenPortDHT}/udp";
          VPN_ENABLED = "true";
          VPN_CONF = "wg0";
          PRIVOXY_ENABLED = "false";
          FLOOD_AUTH = "false";
        };

        extraOptions = [
          "--privileged"
          "--cap-add=NET_ADMIN"
          "--cap-add=SYS_MODULE"
          "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
          "--sysctl=net.ipv6.conf.all.disable_ipv6=0"
        ];

        ports = [
          "${builtins.toString cfg.webPort}:${builtins.toString cfg.webPort}"
        ];

        volumes = [
          "/var/lib/rtorrent:/config"
          "${cfg.downloadDir}:/downloads"
        ];
      };

      # Write to file /var/lib/rtorrent/rtorrent.rc
      system.activationScripts.rtorrentrc = let
        myRtorrentConfig = rtorrentConfig {};
      in {
        deps = ["var"];
        supportsDryActivation = true;
        text = ''
          if [ "$NIXOS_ACTION" = "dry-activate" ]; then
            echo 'copy: ${myRtorrentConfig} -> /var/lib/rtorrent/rtorrent.rc'
            echo 'copy: ${cfg.wireguardConfigFile} -> /var/lib/rtorrent/wireguard/wg0.conf'
            echo 'chown: /var/lib/rtorrent'
          else
            mkdir -p /var/lib/rtorrent /var/lib/rtorrent/wireguard
            cp ${myRtorrentConfig} /var/lib/rtorrent/rtorrent.rc
            cp ${cfg.wireguardConfigFile} /var/lib/rtorrent/wireguard/wg0.conf
            chown 1000:1000 -R /var/lib/rtorrent/
          fi
        '';
      };

      # services.rtorrent = {
      #   enable = false;
      #   package = pkgs.jesec-rtorrent;
      #   inherit (cfg) openFirewall;

      #   inherit (cfg) downloadDir;
      #   port = cfg.listenPort;

      #   configText = ''
      #   dht.port.set = ${builtins.toString cfg.listenPortDHT}
      #   dht.mode.set = auto
      #   protocol.pex.set = yes

      #   protocol.encryption.set = require,require_RC4,allow_incoming,try_outgoing
      #   '';
      # };

      # services.flood = {
      #   enable = false;
      #   port = cfg.webPort;

      #   extraArgs = "--host=0.0.0.0 --auth=none --rtsocket=${config.services.rtorrent.rpcSocket}";
      #   user = "rtorrent";
      #   group = "rtorrent";
      # };

      seedbox.consul.services = [
        {
          id = "ghcr.io-hotio-rflood-latest";
          name = "rtorrent-flood";
          port = cfg.webPort;
          meta = {
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
        # cfg.listenPort
        # cfg.listenPortDHT
      ];
      networking.firewall.allowedUDPPorts = [
        cfg.webPort
        # cfg.listenPort
        # cfg.listenPortDHT
      ];
    })
  ]);
}
