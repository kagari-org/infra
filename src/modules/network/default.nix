{ config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, pkgs, lib, node, name, ... }: {
      networking.useNetworkd = true;
      networking.resolvconf.enable = false;
      networking.nameservers = node.dns;
      services.resolved.enable = true;

      systemd.network.networks."99-ethernet-default-dhcp" = lib.mkIf config.networking.useDHCP {
        dhcpV4Config.UseDNS = false;
        dhcpV6Config.UseDNS = false;
        ipv6AcceptRAConfig.UseDNS = false;
      };
      systemd.network.networks."99-wireless-client-dhcp" = lib.mkIf config.networking.useDHCP {
        dhcpV4Config.UseDNS = false;
        dhcpV6Config.UseDNS = false;
        ipv6AcceptRAConfig.UseDNS = false;
      };
      # https://github.com/NixOS/nixpkgs/issues/69414
      systemd.network.networks."80-container-ve".enable = false;

      networking.nftables.enable = true;
      networking.nftables.checkRuleset = false;
      networking.firewall.checkReversePath = false;
      networking.firewall.trustedInterfaces = [ "cn0" ];
      networking.firewall.extraForwardRules = ''
        iifname { "ve-*", "svc-*" } accept
        iifname "cn0" oifname { "ve-*", "svc-*" } accept
      '';
      networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
        "net.ipv6.conf.all.forwarding" = 1;
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
        matchConfig.Name = "cn0";
        address = [ "${node.igp-v4}/24" "${node.igp-v6}/128" ];
      };

      services.namae.records = [
        {
          inherit name;
          type = "A";
          from-interface = "cn0";
        }
        {
          inherit name;
          type = "AAAA";
          from-interface = "cn0";
        }
      ];

      sops.secrets.cryonet-env.sopsFile = ./secrets.yaml;
      systemd.slices.cryonet.wantedBy = [ "nftables.service" ];
      environment.systemPackages = [ inputs'.cryonet.packages.default ];
      systemd.services.cryonet = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          TAP_MODE = "true";
          SERVERS = infra.nodes
            |> lib.attrValues
            |> lib.filter (x: x.id != node.id && x.cryonet.bootstrap)
            |> lib.map (x: "wss://${x.address}:16809")
            |> lib.concatStringsSep ",";
          CANDIDATE_FILTER_PREFIXES = "10.0.0.0/8";
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
        email = "void@anil.lc";
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
          hash = "sha256-5a5cpFl90pEWt0lUC4ZJQ7g+1//ZvsRhee64Dt9vh5o=";
        };
        environmentFile = config.sops.secrets.caddy-env.path;
        virtualHosts.cryonet = {
          hostName = "${node.address}:16809";
          extraConfig = ''
            reverse_proxy 127.0.0.1:2333
            tls {
              alpn http/1.1
              dns cloudflare {$CLOUDFLARE_API_TOKEN}
            }
          '';
        };
      };

      systemd.network.networks.loopback = {
        matchConfig.Name = "lo";
        address = [ "${node.igp-v4}/32" ];
      };

      services.bird = {
        enable = true;
        checkConfig = false;
        config = ''
          router id ${node.igp-v4};
          ipv4 table igp_v4;
          ipv6 table igp_v6;
          protocol device {}
          protocol kernel kernel4 {
              learn;
              ipv4 {
                  import all;
                  export all;
              };
          }
          protocol kernel kernel6 {
              ipv6 {
                  import all;
                  export all;
              };
          }
          protocol pipe pipe4 {
              table igp_v4;
              peer table master4;
              import none;
              export all;
          }
          protocol pipe pipe6 {
              table igp_v6;
              peer table master6;
              import none;
              export all;
          }

          protocol direct {
            interface "cn0";
            ipv6 {
              table igp_v6;
              import filter {
                if net ~ [ ${node.ula-prefix}/64+ ] then accept;
                reject;
              };
            };
          }

          protocol babel {
            interface "cn0" {
              type wireless;
              hello interval 10 s;
              update interval 40 s;
              rtt cost 160;
              rtt min 40 ms;
              rtt max 120 ms;
              rtt decay 8;
            };
            ipv4 {
              table igp_v4;
              import filter {
                krt_prefsrc = ${node.igp-v4};
                accept;
              };
              export all;
            };
            ipv6 {
              table igp_v6;
              import all;
              export all;
            };
          }

          protocol static {
            route ${node.igp-v4}/32 via "lo";
            ipv4 { table igp_v4; };
          }

          include "/run/bird-services.d/*.conf";
        '';
      };
    });
  } ];
}
