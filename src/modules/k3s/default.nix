{ self, config, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    tags = [ "nixos" "k3s" ];
    module = { config, pkgs, lib, name, node, ... }: {
      networking.firewall.trustedInterfaces = [ "cali*" ];
      sops.secrets.k3s-token.sopsFile = ./secrets.yaml;

      # for longhorn
      systemd.tmpfiles.rules = [ "L+ /usr/local/bin - - - - /run/current-system/sw/bin/" ];
      environment.systemPackages = [ pkgs.nfs-utils ];
      services.openiscsi = {
        enable = true;
        name = "${config.networking.hostName}-initiatorhost";
      };

      systemd.services.k3s.serviceConfig.TimeoutStartSec = "5m";
      systemd.services.k3s.after = [ "cryonet.service" ];
      services.k3s = let
        init-node = infra.nodes
            |> lib.attrValues
            |> lib.filter (x: x.k3s.endpoint)
            |> (nodes: assert lib.length nodes == 1; nodes)
            |> lib.flip lib.elemAt 0
            |> (node: assert node.k3s.server; node);
      in {
        enable = true;
        tokenFile = config.sops.secrets.k3s-token.path;
        role = if node.k3s.server then "server" else "agent";
        clusterInit = init-node.id == node.id;
        serverAddr = lib.optionalString (init-node.id != node.id) "https://${init-node.igp-v4}:6443";
        extraFlags = [
          "--node-ip=${node.igp-v4}" "--node-name=${name}"
        ] ++ (lib.optionals node.k3s.server [
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable=coredns"
          "--disable=local-storage"
          "--disable=metrics-server"
          "--disable=traefik"
          # enabling: servicelb ccm
        ]);
        manifests = lib.mkIf node.k3s.server {
          manifest.source = self.packages.${pkgs.system}.manifest;
        };
      };
    };
  } ];
}
