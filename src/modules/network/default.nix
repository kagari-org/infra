{ inputs, config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, pkgs, lib, node, ... }: {
      networking.useNetworkd = true;
      networking.nftables.enable = true;
      networking.nftables.checkRuleset = false;
      networking.firewall.checkReversePath = false;
      networking.firewall.trustedInterfaces = [ "cn*" ];
      networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];
      networking.resolvconf.extraConfig = ''
        name_servers="8.8.8.8 8.8.4.4"
      '';
      services.resolved.enable = false;
      # TODO: networking.getaddrinfo in 25.11
      environment.etc."gai.conf".text = ''
        precedence ::ffff:0:0/96 100
      '';

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
      };

      # allow udp ports from cryonet
      networking.nftables.tables.nixos-fw.content = lib.mkBefore ''
        set cryonet-ports {
          type inet_service;
          flags dynamic;
          timeout 1d;
        }
        chain cryonet-output {
          type route hook output priority filter; policy accept;
          socket cgroupv2 level 1 "cryonet.slice" add @cryonet-ports { udp sport }
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
      systemd.services.cryonet = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          WS_SERVERS = infra.nodes
            |> lib.attrValues
            |> lib.filter (x: x.id != node.id && x.cryonet.bootstrap)
            |> lib.map (x: "wss://${x.address}:18443")
            |> lib.concatStringsSep ",";
          ICE_SERVERS = "stun:stun.l.google.com,stun:stun.miwifi.com";
        };
        serviceConfig = {
          Restart = "always";
          EnvironmentFile = config.sops.secrets.cryonet-env.path;
          ExecStart = "${inputs'.cryonet.packages.default}/bin/cryonet ${toString node.id}";
          Slice = "cryonet.slice";
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf node.cryonet.bootstrap [ 18443 ];
      sops.secrets.caddy-env = lib.mkIf node.cryonet.bootstrap {
        sopsFile = ./secrets.yaml;
        owner = "caddy";
        group = "caddy";
      };
      services.caddy = lib.mkIf node.cryonet.bootstrap {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
          hash = "sha256-Gsuo+ripJSgKSYOM9/yl6Kt/6BFCA6BuTDvPdteinAI=";
        };
        environmentFile = config.sops.secrets.caddy-env.path;
        globalConfig = ''
          http_port 18080
          https_port 18443
        '';
        virtualHosts.${node.address}.extraConfig = ''
          reverse_proxy 127.0.0.1:2333
          tls {
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
        package = pkgs.bird3.overrideAttrs (old: {
          patches = old.patches ++ [ ./proto.patch ];
        });
        config = ''
          router id ${node.igp-v4};
          ipv4 table igp_v4;
          ipv6 table igp_v6;
          protocol device {}
          protocol direct { ipv4; ipv6; }
          protocol kernel {
              learn;
              ipv4 {
                  import all;
                  export all;
              };
          }
          protocol kernel {
              learn;
              ipv6 {
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
          protocol pipe {
              table igp_v6;
              peer table master6;
              import none;
              export all;
          }

          protocol babel {
            interface "cn*" {
              type tunnel;
            };
            ipv4 {
              table igp_v4;
              import filter {
                krt_prefsrc = ${node.igp-v4};
                accept;
              };
              export where (source = RTS_STATIC) || (source = RTS_BABEL);
            };
            ipv6 {
              table igp_v6;
              import all;
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
