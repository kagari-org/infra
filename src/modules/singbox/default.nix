{
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, node, ... }: let
      singbox-config = pkgs.writeText "config.json" (lib.generators.toJSON {} {
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
        experimental.clash_api.external_controller = "0.0.0.0:9090";

        dns = {
          servers = [
            { tag = "s_cf"; address = "tls://1.0.0.1"; }
            { tag = "s_local"; address = "udp://223.5.5.5"; detour = "s_direct"; }
          ];
          rules = [
            # TODO: migrate to default_domain_resolver, sing-box 1.12.0
            { outbound = "any"; server = "s_local"; }
            { rule_set = "s_geosite-cn"; server = "s_local"; }

            { domain_suffix = "kagari.org"; server = "s_local"; }
          ];
          final = "s_cf";
          client_subnet = "114.114.114.114/24";
        };

        inbounds = [ {
          type = "tproxy";
          tag = "s_tproxy-in";
          listen_port = 9898;
        } ];

        outbounds = [
          {
            type = "selector";
            tag = "s_out";
            outbounds = [ "s_auto" "s_select" "s_direct" ];
            default = "s_auto";
          }
          { type = "direct"; tag = "s_direct"; }
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
            # bypass allowed ports for forwarding packets
            ${lib.optionalString (lib.length config.networking.firewall.allowedTCPPorts != 0) ''
              iifname "cali*" tcp sport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedTCPPorts)} } return
              oifname "cali*" tcp dport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedTCPPorts)} } return
            ''}
            ${lib.optionalString (lib.length config.networking.firewall.allowedUDPPorts != 0) ''
              iifname "cali*" udp sport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedUDPPorts)} } return
              oifname "cali*" udp dport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedUDPPorts)} } return
            ''}
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

        # cat ~/sub.json | sops encrypt --input-type binary --filename-override src/modules/singbox/secrets.yaml > src/modules/singbox/secrets.yaml
        # then rename data to singbox-sub
        sops.secrets.singbox-sub.sopsFile = ./secrets.yaml;
        services.sing-box.enable = true;
        systemd.services.sing-box = {
          path = with pkgs; [ jq ];
          serviceConfig.LoadCredential = "sub:${config.sops.secrets.singbox-sub.path}";
          preStart = lib.mkForce ''
            export OUTBOUNDS=$(mktemp)
            jq -r '[.outbounds[] | select(.type | contains("vmess", "shadowsocks"))]' \
              $CREDENTIALS_DIRECTORY/sub > $OUTBOUNDS
            export SELECT=$(mktemp)
            jq -r '[[.[].tag] | {tag: "s_select", type: "selector", outbounds: .}]' $OUTBOUNDS > $SELECT
            export URLTEST=$(mktemp)
            jq -r '[[.[].tag] | {tag: "s_auto", type: "urltest", outbounds: .}]' $OUTBOUNDS > $URLTEST

            cat ${singbox-config} $SELECT $URLTEST $OUTBOUNDS | jq -s -r '
              .[0].outbounds += .[1] + .[2] + .[3] | .[0]
            ' > /run/sing-box/config.json
          '';
        };
      };
    };
  } ];
}
