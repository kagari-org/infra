{ config, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, name, node, ... }: let
      cidr = "10.16.0.0/15";
      cluster-cidr = "10.16.${toString node.id}.0/24";
      service-cidr = "10.17.${toString node.id}.0/24";
      cluster-dns  = "10.17.${toString node.id}.10";
    in lib.mkMerge [
      (lib.mkIf node.k3s.control {
        sops.secrets.etcd-ca-crt = {
          owner = "etcd";
          group = "etcd";
          sopsFile = ./secrets.yaml;
        };
        sops.secrets.etcd-key = {
          owner = "etcd";
          group = "etcd";
          sopsFile = ./secrets.yaml;
        };
        sops.secrets.etcd-crt = {
          owner = "etcd";
          group = "etcd";
          sopsFile = ./secrets.yaml;
        };
        services.etcd = {
          inherit name;
          enable = true;

          # tls
          trustedCaFile = config.sops.secrets.etcd-ca-crt.path;
          keyFile = config.sops.secrets.etcd-key.path;
          certFile = config.sops.secrets.etcd-crt.path;
          clientCertAuth = true;
          peerClientCertAuth = true;

          listenClientUrls = [ "https://127.0.0.1:2379" "https://${node.igp-v4}:2379" ];
          listenPeerUrls = [ "https://${node.igp-v4}:2380" ];
          initialCluster = infra.nodes
            |> lib.filterAttrs (_: node: node.k3s.control)
            |> lib.mapAttrsToList (name: node: "${name}=https://${node.igp-v4}:2380");
          extraConf = {
            HEARTBEAT_INTERVAL = "1000";
            ELECTION_TIMEOUT = "30000";
          };
        };

        sops.secrets.karmada-certs.sopsFile = ./secrets.yaml;
        services.k3s = {
          manifests.karmada-certs.source = config.sops.secrets.karmada-certs.path;
          # karmadactl join ${name} --cluster-kubeconfig /etc/cluster/kubeconfig
          autoDeployCharts.karmada = {
            name = "karmada";
            package = pkgs.fetchurl {
              url = "https://github.com/kagari-org/karmada/releases/download/v1.18.0/karmada-chart-v1.18.0.tgz";
              hash = "sha256-LoOmXXQCkOrkfDaF1GsVbAajcpkPCSfaylLCftRXPrE=";
            };
            targetNamespace = "karmada-system";
            createNamespace = true;
            values = {
              etcd = {
                mode = "external";
                external.servers = "https://${node.igp-v4}:2379";
              };
              certs.mode = "custom";
              apiServer.resources = {
                requests.memory = "128Mi";
                limits.memory = "1Gi";
              };
              controllerManager.featureGates.PropagateDeps = true;
            };
            extraFieldDefinitions.spec.valuesSecrets = [ {
              name = "karmada-certs";
              keys = [ "karmada-certs" ];
            } ];
          };
        };
      })
      {
        services.bird.config = lib.mkAfter ''
          protocol static cluster {
            route ${cluster-cidr} blackhole;
            route ${service-cidr} blackhole;
            ipv4 { table igp_v4; };
          };
        '';

        sops.secrets.k3s-token.sopsFile = ./secrets.yaml;
        networking.firewall.trustedInterfaces = [ "lxc*" "cilium*" ];
        services.k3s = {
          enable = true;
          role = "server";
          tokenFile = config.sops.secrets.k3s-token.path;
          disable = [ "traefik" "servicelb" ];
          configPath = pkgs.writeText "k3s-config.yaml" (lib.generators.toYAML {} {
            inherit cluster-cidr service-cidr cluster-dns;
            node-ip = node.igp-v4;
            node-name = name;

            flannel-backend = "none";
            disable-network-policy = true;
            disable-kube-proxy = true;
          });
          extraKubeletConfig = {
            featureGates.NodeSwap = true;
            memorySwap.swapBehavior = "LimitedSwap";
          };
          autoDeployCharts.cilium = {
            name = "cilium";
            repo = "https://helm.cilium.io";
            version = "1.19.4";
            hash = "sha256-xqeI5r10WYojX3mHkwhg9VTC3YBIFU0auopTK83pDNY=";
            targetNamespace = "kube-system";
            createNamespace = true;
            extraFieldDefinitions.spec.bootstrap = true;
            values = {
              operator.replicas = 1;

              k8sServiceHost = node.igp-v4;
              k8sServicePort = "6443";
              kubeProxyReplacement = "true";

              devices = lib.mkDefault "cn0";
              forceDeviceDetection = true;
              ipv4NativeRoutingCIDR = cidr;
              nodePort.directRoutingDevice = "cn0";
              routingMode = "native";

              ipam.operator.clusterPoolIPv4PodCIDRList = [ cluster-cidr ];
              nodeIPAM.enabled = true;

              defaultLBServiceIPAM = "nodeipam";
              enableLBIPAM = false;

              bpf.lbExternalClusterIP = true;
            };
          };
        };
      }
    ];
  } ];
}
