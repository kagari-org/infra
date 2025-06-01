{ config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    tags = [ "nixos" ];
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, lib, nixos, ... }: {
      networking.useNetworkd = true;
      networking.nftables.enable = true;
      networking.firewall.checkReversePath = false;
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
      };

      sops.secrets.cryonet-env.sopsFile = ./secrets.yaml;
      systemd.services.cryonet = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          WS_SERVERS = infra.nixos
            |> lib.attrValues
            |> lib.filter (x: x.id != nixos.id && x.cryonet-bootstrap)
            |> lib.map (x: "wss://${x.hostname}")
            |> lib.concatStringsSep ",";
          ICE_SERVERS = "stun:stun.l.google.com";
        };
        serviceConfig = {
          EnvironmentFile = config.sops.secrets.cryonet-env.path;
          ExecStart = "${inputs'.cryonet.packages.default}/bin/cryonet ${toString nixos.id}";
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf nixos.cryonet-bootstrap [ 80 443 ];
      services.caddy = lib.mkIf nixos.cryonet-bootstrap {
        enable = true;
        virtualHosts.${nixos.hostname}.extraConfig = ''
          reverse_proxy 127.0.0.1:2333
        '';
      };

      systemd.network.networks.loopback = {
        matchConfig.Name = "lo";
        address = [ nixos.igp-v4 ];
      };
      services.bird = {
        enable = true;
        config = ''
          router id ${nixos.igp-v4};
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
                krt_prefsrc = ${nixos.igp-v4};
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
            route ${nixos.igp-v4}/32 via "lo";
            ipv4 { table igp_v4; };
          }
        '';
      };
    });
  } ];
}
