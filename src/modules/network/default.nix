{ config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = withSystem "x86_64-linux" ({ inputs', self', ... }: { config, pkgs, lib, node, ... }: {
      networking.useNetworkd = true;
      networking.resolvconf.enable = false;
      services.resolved.enable = false;
      environment.etc."resolv.conf".text = node.dns
        |> lib.map (d: "nameserver ${d}")
        |> lib.concatStringsSep "\n";

      networking.nftables.enable = true;
      networking.nftables.checkRuleset = false;
      networking.firewall.checkReversePath = false;
      networking.firewall.trustedInterfaces = [ "cn*" ];
      networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };

      # allow udp ports from cryonet
      networking.nftables.tables.nixos-fw.content = lib.mkBefore ''
        set cryonet-ports {
          type inet_service;
          flags dynamic;
          timeout 1d;
        }
        chain cryonet-output {
          type route hook output priority mangle; policy accept;
          socket cgroupv2 level 1 "cryonet.slice" add @cryonet-ports { udp sport }
          ${lib.optionalString node.singbox.enable ''
            socket cgroupv2 level 1 "cryonet.slice" ct mark set ${toString node.singbox.direct}
          ''}
        }
      '';
      networking.firewall.extraInputRules = ''
        udp dport @cryonet-ports accept
      '';

      systemd.network.networks.cryonet = {
        matchConfig.Name = "cn*";
        address = [ "${node.igp-v4}/24" ];
      };

      sops.secrets.cryonet-env.sopsFile = ./secrets.yaml;
      systemd.slices.cryonet.wantedBy = [ "nftables.service" ];
      environment.systemPackages = [ inputs'.cryonet.packages.default ];
      systemd.services.cryonet = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          RUST_LOG = "debug";
          SERVERS = infra.nodes
            |> lib.attrValues
            |> lib.filter (x: x.id != node.id && x.cryonet.bootstrap)
            |> lib.map (x: "wss://${x.address}:16809")
            |> lib.concatStringsSep ",";
          CANDIDATE_FILTER_PREFIX = "10.11.0.0/16";
        };
        serviceConfig = {
          Restart = "always";
          EnvironmentFile = config.sops.secrets.cryonet-env.path;
          ExecStart = "${inputs'.cryonet.packages.default}/bin/cryonet ${toString node.id}";
          Slice = "cryonet.slice";
          RuntimeDirectory = "cryonet";
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf node.cryonet.bootstrap [ 16809 ];
      sops.secrets.caddy-env = lib.mkIf node.cryonet.bootstrap {
        sopsFile = ./secrets.yaml;
        owner = "caddy";
        group = "caddy";
      };
      services.caddy = lib.mkIf node.cryonet.bootstrap {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
          hash = "sha256-vNSHU7txQLs0m0UChuszURXjEoMj4r1902+1ei0/DaI=";
        };
        environmentFile = config.sops.secrets.caddy-env.path;
        globalConfig = ''
          http_port 18080
          https_port 16809
        '';
        virtualHosts.${node.address}.extraConfig = ''
          reverse_proxy 127.0.0.1:2333
          tls {
            alpn http/1.1
            dns cloudflare {$CLOUDFLARE_API_TOKEN}
          }
        '';
      };

      systemd.network.networks.loopback = {
        matchConfig.Name = "lo";
        address = [ "${node.igp-v4}/32" ];
      };

      services.bird = {
        enable = true;
        config = ''
          router id ${node.igp-v4};
          ipv4 table igp_v4;
          protocol device {}
          protocol kernel {
              learn;
              ipv4 {
                  import all;
                  export all;
              };
          }
          protocol pipe {
              table igp_v4;
              peer table master4;
              import none;
              export all;
          }

          protocol babel {
            interface "cn*" { type tunnel; };
            ipv4 {
              table igp_v4;
              import filter {
                krt_prefsrc = ${node.igp-v4};
                accept;
              };
              export where (source = RTS_STATIC) || (source = RTS_BABEL);
            };
          }

          protocol static {
            route ${node.igp-v4}/32 via "lo";
            ipv4 { table igp_v4; };
          }
        '';
      };
    });
  } ];
}
