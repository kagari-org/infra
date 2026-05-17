{ config, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    type = "nixos";
    module = { lib, name, node, ... }: {
      services.etcd = {
        inherit name;
        enable = true;
        listenClientUrls = [ "http://127.0.0.1:2379" "http://${node.igp-v4}:2379" ];
        listenPeerUrls = [ "http://${node.igp-v4}:2380" ];
        initialCluster = infra.nodes
          |> lib.mapAttrsToList (name: node: "${name}=http://${node.igp-v4}:2380");
      };
    };
  } ];
}
