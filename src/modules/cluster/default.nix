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
    in {
      services.bird.config = lib.mkAfter ''
        protocol static cluster {
          route ${cluster-cidr} blackhole;
          route ${service-cidr} blackhole;
          ipv4 { table igp_v4; };
        };
      '';

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
          |> lib.mapAttrsToList (name: node: "${name}=https://${node.igp-v4}:2380");
        extraConf = {
          HEARTBEAT_INTERVAL = "1000";
          ELECTION_TIMEOUT = "30000";
        };
      };

      sops.secrets.k3s-token.sopsFile = ./secrets.yaml;
      sops.secrets.karmada-certs.sopsFile = ./secrets.yaml;
      networking.firewall.trustedInterfaces = [ "lxc*" "cilium*" ];
      services.k3s = {
        enable = true;
        role = "server";
        tokenFile = config.sops.secrets.k3s-token.path;
        disable = [ "traefik" ];
        configPath = pkgs.writeText "k3s-config.yaml" (lib.generators.toYAML {} {
          inherit cluster-cidr service-cidr cluster-dns;
          node-ip = node.igp-v4;
          node-name = name;

          flannel-backend = "none";
          disable-network-policy = true;
          disable-kube-proxy = true;
        });
        manifests.karmada-certs.source = config.sops.secrets.karmada-certs.path;
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
            ipam.operator.clusterPoolIPv4PodCIDRList = [ cluster-cidr ];
            routingMode = "native";
            ipv4NativeRoutingCIDR = cidr;
            nodeIPAM.enabled = false;
            enableLBIPAM = false;
            defaultLBServiceIPAM = "none";
            kubeProxyReplacement = "true";
          };
        };
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
          };
          extraFieldDefinitions.spec.valuesSecrets = [ {
            name = "karmada-certs";
            keys = [ "karmada-certs" ];
          } ];
          extraDeploy = [ {
            apiVersion = "batch/v1";
            kind = "Job";
            metadata = {
              name = "join-karmada";
              namespace = "karmada-system";
            };
            spec.template.spec = {
              restartPolicy = "OnFailure";
              containers = [ {
                name = "join-karmada";
                image = "alpine";
                command = [
                  "sh" "-c" ''
                    apk update && apk add curl
                    curl -L -o k.tgz https://github.com/karmada-io/karmada/releases/download/v1.18.0-rc.0/karmadactl-linux-amd64.tgz
                    tar xvf k.tgz
                    export KUBECONFIG=/etc/karmada/kubeconfig
                    # skip if we have joined
                    ./karmadactl get cluster ${name} && exit 0
                    ./karmadactl join ${name} --cluster-kubeconfig /etc/cluster/kubeconfig
                  ''
                ];
                volumeMounts = [
                  { name = "karmada-kubeconfig"; mountPath = "/etc/karmada"; }
                  { name = "cluster-kubeconfig"; mountPath = "/etc/cluster"; }
                ];
              } ];
              volumes = [
                { name = "karmada-kubeconfig"; secret.secretName = "karmada-kubeconfig"; }
                { name = "cluster-kubeconfig"; secret.secretName = "cluster-kubeconfig"; }
              ];
            };
          } ];
        };
      };
      systemd.services.kubeconfig-secret = {
        wantedBy = [ "multi-user.target" ];
        after = [ "k3s.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
        path = with pkgs; [ k3s yq-go ];
        script = ''
          KUBECONFIG="$(yq '.clusters[0].cluster.server = "https://${node.igp-v4}:6443"' /etc/rancher/k3s/k3s.yaml)"
          k3s kubectl create -n karmada-system secret generic cluster-kubeconfig \
            --from-literal=kubeconfig="$KUBECONFIG" \
            --dry-run=client -o yaml | k3s kubectl apply -f -
        '';
      };
    };
  } ];
}
