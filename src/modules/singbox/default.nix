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
            path = "${pkgs.sing-geosite}/share/sing-box/rule-set/geosite-cn.srs";
          }
        ];
        experimental.clash_api.external_controller = "0.0.0.0:9090";

        dns = {
          servers = [
            { tag = "s_google"; address = "tls://8.8.8.8"; }
            { tag = "s_local"; address = "local"; detour = "s_direct"; }
          ];
          rules = [
            { outbound = "s_select"; server = "s_google"; }
          ];
          final = "s_local";
        };

        inbounds = [ {
          type = "tproxy";
          tag = "s_tproxy-in";
          listen_port = 9898;
        } ];

        outbounds = [
          {
            type = "selector";
            tag = "s_select";
            outbounds = [ "s_auto" "s_direct" ];
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
          ];
          final = "s_select";
          auto_detect_interface = true;
        };
      });
    in {
      config = lib.mkIf node.singbox.enable {
        sops.secrets.singbox-sub.sopsFile = ./secrets.yaml;
        services.sing-box.enable = true;
        systemd.services.sing-box = {
          path = with pkgs; [ jq ];
          serviceConfig.LoadCredential = "sub:${config.sops.secrets.singbox-sub.path}";
          preStart = lib.mkForce ''
            export OUTBOUNDS=$(mktemp)
            jq -r '[.outbounds[] | select(.type | contains("vmess", "shadowsocks"))]' \
              $CREDENTIALS_DIRECTORY/sub > $OUTBOUNDS
            export URLTEST=$(mktemp)
            jq -r '[[.[].tag] | {tag: "s_auto", type: "urltest", outbounds: .}]' $OUTBOUNDS > $URLTEST

            cat ${singbox-config} $URLTEST $OUTBOUNDS | jq -s -r '
              .[0].outbounds += .[1] + .[2] | .[0]
            ' > /run/sing-box/config.json
          '';
        };
      };
    };
  } ];
}
