{ self, config, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, name, node, ... }: {
      config = lib.mkIf node.k3s.enable {
        networking.firewall.allowedTCPPorts = [ 80 443 ];
        networking.firewall.trustedInterfaces = [ "cali*" ];

        # for longhorn
        boot.kernelModules = [ "dm_crypt" ];
        systemd.tmpfiles.rules = [ "L+ /usr/local/bin - - - - /run/current-system/sw/bin/" ];
        environment.systemPackages = [ pkgs.nfs-utils ];
        services.openiscsi = {
          enable = true;
          name = "${config.networking.hostName}-initiatorhost";
        };

        boot.kernel.sysctl = {
          "fs.inotify.max_user_instances" = 1024;
          # https://github.com/kubernetes/kubernetes/issues/94861
          # https://github.com/kubernetes/kubernetes/pull/120412
          "net.netfilter.nf_conntrack_tcp_be_liberal" = 1;
        };

        systemd.services.k3s-disk-file = let
          disks = pkgs.writeTextDir "disks.json" (lib.generators.toJSON {} node.k3s.disks);
          conf = pkgs.writeText "lighttpd.conf" ''
            server.port = 18081
            server.document-root = "${disks}" 
          '';
        in {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.lighttpd}/bin/lighttpd -D -f ${conf}";
            ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR1 $MAINPID";
            KillSignal = "SIGINT";
          };
        };

        sops.secrets.k3s-token.sopsFile = ./secrets.yaml;
        systemd.services.k3s.serviceConfig.TimeoutStartSec = "5m";
        systemd.services.k3s.after = [ "cryonet.service" ];
        services.k3s = let
          init-node = infra.nodes
            |> lib.attrValues
            |> lib.filter (x: x.k3s.endpoint)
            |> (nodes: assert lib.length nodes == 1; nodes)
            |> lib.flip lib.elemAt 0
            |> (node: assert node.k3s.server; node);
          extraManifests = infra.nodes
            |> lib.attrValues
            |> map (x: x.k3s.extraManifests)
            |> lib.mergeAttrsList;
        in {
          enable = true;
          tokenFile = config.sops.secrets.k3s-token.path;
          role = if node.k3s.server then "server" else "agent";
          clusterInit = init-node.id == node.id;
          serverAddr = lib.optionalString (init-node.id != node.id) "https://${init-node.igp-v4}:6443";
          configPath = pkgs.writeText "k3s-config.yaml" (lib.generators.toYAML {} ({
            node-ip = node.igp-v4;
            node-name = name;
            node-label = [
              "topology.kubernetes.io/zone=${node.k3s.zone}"
              "node.longhorn.io/create-default-disk=config"
            ];
          } // lib.optionalAttrs node.k3s.server {
            flannel-backend = "none";
            disable-network-policy = true;
            disable-helm-controller = true;
            disable = [ "local-storage" "coredns" "metrics-server" "traefik" ];
            # enabling: servicelb ccm
          }));
          extraKubeletConfig = {
            featureGates.NodeSwap = true;
            memorySwap.swapBehavior = "LimitedSwap";
          };
          manifests = lib.mkIf node.k3s.server ({
            manifest.source = self.packages.${pkgs.system}.manifest;
          } // extraManifests);
        };
      };
    };
  } ];
}
