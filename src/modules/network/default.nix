{ config, withSystem, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    tags = [ "nixos" ];
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, lib, name, nixos, ... }: {
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
        environment.WS_SERVERS = infra.nixos
          |> lib.filterAttrs (n: v: n != name && v.cryonet-bootstrap)
          |> lib.mapAttrsToList (_: v: "wss://${v.hostname}")
          |> lib.concatStringsSep ",";
        serviceConfig = {
          EnvironmentFile = config.sops.secrets.cryonet-env.path;
          ExecStart = "${inputs'.cryonet.packages.default}/bin/cryonet ${name}";
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf nixos.cryonet-bootstrap [ 80 443 ];
      services.caddy = lib.mkIf nixos.cryonet-bootstrap {
        enable = true;
        virtualHosts.${nixos.hostname}.extraConfig = ''
          reverse_proxy 127.0.0.1:2333
        '';
      };
    });
  } ];
}
