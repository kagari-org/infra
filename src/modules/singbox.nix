{ config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, pkgs, lib, node, name, ... }: let
      template = pkgs.writeText "sing-box-template.json" (lib.generators.toJSON {} {
        route.rule_set = [
          {
            type = "local";
            tag = "s_geoip-cn";
            format = "binary";
            path = "${pkgs.sing-geoip}/share/sing-box/rule-set/geoip-cn.srs";
          }
          {
            type = "local";
            tag = "s_geosite-cn";
            format = "binary";
            path = "${pkgs.sing-geosite}/share/sing-box/rule-set/geosite-geolocation-cn.srs";
          }
        ];

        experimental.clash_api.external_controller = "127.0.0.1:9090";

        services = [
          {
            type = "api";
            tag = "s_api";
            listen = "127.0.0.1";
            listen_port = 9091;
          }
        ];

        dns = {
          servers = [
            { tag = "s_cf"; type = "https"; server = "1.0.0.1"; detour = "s_out"; }
            { tag = "s_local"; type = "udp"; server = "223.5.5.5"; }
          ];
          rules = [
            { rule_set = "s_geosite-cn"; server = "s_local"; }

            { domain_suffix = "kagari.org"; server = "s_local"; }
          ];
          final = "s_cf";
          client_subnet = "114.114.114.114/24";
        };

        inbounds = [
          {
            type = "tproxy";
            tag = "s_tproxy-in";
            listen_port = 9898;
          }
          {
            type = "mixed";
            tag = "s_mmixed-in";
            listen_port = 7897;
          }
        ];

        route = {
          rules = [
            { action = "sniff"; }
            { action =  "hijack-dns"; protocol = "dns"; }
            { rule_set = "s_geoip-cn"; outbound = "s_direct"; }
            { rule_set = "s_geosite-cn"; outbound = "s_direct"; }
            { ip_is_private = true; outbound = "s_direct"; }

            { domain = "la13-idrive.kagari.org"; outbound = "s_direct"; }
            { domain = "sg01-idrive.kagari.org"; outbound = "s_direct"; }
          ];
          final = "s_out";
          auto_detect_interface = true;
          # resolve domains of outbound addresses
          default_domain_resolver = "s_local";
        };
      });
    in {
      config = lib.mkIf node.singbox.enable {
        networking.firewall.extraInputRules = ''
          # accept packets redirected from prerouting
          meta mark ${toString node.singbox.mark} accept
        '';
        networking.nftables.tables.nixos-fw.content = lib.mkAfter ''
          define RESERVED_IP = {
              0.0.0.0/8,       # RFC 1122 'this' network
              10.0.0.0/8,      # RFC 1918 private space
              100.64.0.0/10,   # RFC 6598 Carrier grade nat space
              127.0.0.0/8,     # RFC 1122 localhost
              169.254.0.0/16,  # RFC 3927 link local
              172.16.0.0/12,   # RFC 1918 private space
              192.0.2.0/24,    # RFC 5737 TEST-NET-1
              192.88.99.0/24,  # RFC 7526 6to4 anycast relay
              192.168.0.0/16,  # RFC 1918 private space
              198.18.0.0/15,   # RFC 2544 benchmarking
              198.51.100.0/24, # RFC 5737 TEST-NET-2
              203.0.113.0/24,  # RFC 5737 TEST-NET-3
              224.0.0.0/4,     # multicast
              240.0.0.0/4,     # reserved
          }
          chain singbox-input {
            type filter hook input priority mangle + 100; policy accept;
            # mark new connection from outside
            # tproxy will redirect output packets to input
            # we need make real input packets goto machine self
            meta mark != ${toString node.singbox.mark} ct state new ct mark set ${toString node.singbox.direct}
          }
          chain singbox-output {
            type route hook output priority filter + 100; policy accept;
            # accept input connections
            ct mark ${toString node.singbox.direct} return
            # bypass reserved ips but dns queries
            ip daddr $RESERVED_IP udp dport != 53 return
            ip daddr $RESERVED_IP tcp dport != 53 return
            # lookup node.singbox.table, redirect to local
            ip protocol { tcp, udp } meta mark set ${toString node.singbox.mark}
          }
          chain singbox-prerouting {
            type filter hook prerouting priority mangle + 100; policy accept;
            ip daddr $RESERVED_IP return
            ip protocol { tcp, udp } meta mark set ${toString node.singbox.mark} tproxy ip to 127.0.0.1:9898
          }
        '';
        systemd.network.networks.loopback = {
          routes = [ {
            Destination = "0.0.0.0/0";
            Type = "local";
            Table = node.singbox.table;
          } ];
          routingPolicyRules = [ {
            FirewallMark = node.singbox.mark;
            Table = node.singbox.table;
          } ];
        };

        services.sing-box.enable = true;
        systemd.services.sing-portal-agent = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          before = [ "sing-box.service" ];
          wants = [ "network-online.target" ];
          path = [
            inputs'.sing-portal.packages.default
            config.systemd.package
          ];
          script = ''
            exec sing-portal agent \
              --portal ${lib.escapeShellArg "ws://${infra.nodes.home.igp-v4}:3015"} \
              --name ${lib.escapeShellArg name} \
              --template ${template} \
              --config /etc/sing-box/config.json \
              --state-dir /var/lib/sing-portal-agent \
              --api-url http://127.0.0.1:9091 \
              --restart-cmd ${lib.escapeShellArg "systemctl restart sing-box"} \
              --interval 15s
          '';
          serviceConfig = {
            StateDirectory = "sing-portal-agent";
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
    });
  } ];
}
