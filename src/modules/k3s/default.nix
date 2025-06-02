{ config, ... }: let
  inherit (config) infra;
in {
  infra.modules = [ {
    tags = [ "nixos" "k3s" ];
    module = { config, pkgs, lib, nixos, ... }: {
      networking.firewall.trustedInterfaces = [ "cali*" ];
      sops.secrets.k3s-token.sopsFile = ./secrets.yaml;
      services.k3s = let
        init-node = infra.nixos
            |> lib.attrValues
            |> lib.filter (x: x.k3s.endpoint)
            |> (nodes: assert lib.length nodes == 1; nodes)
            |> lib.flip lib.elemAt 0
            |> (node: assert node.k3s.server; node);
      in {
        enable = true;
        tokenFile = config.sops.secrets.k3s-token.path;
        role = if nixos.k3s.server then "server" else "agent";
        clusterInit = init-node.id == nixos.id;
        serverAddr = if init-node.id != nixos.id then "https://${init-node.igp-v4}:6443" else "";
        extraFlags = [ "--node-ip=${nixos.igp-v4}" ]
          ++ (lib.optional nixos.k3s.server "--flannel-backend=none")
          ++ (lib.optional nixos.k3s.server "--disable-network-policy")
          ++ (lib.optional nixos.k3s.server "--disable=traefik");
        manifests.calico.source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/projectcalico/calico/v3.30.1/manifests/calico.yaml";
          hash = "sha256-b8mamxjzufh495gfOEx7t8hpx5ptoReBoqjVC+954vs=";
        };
      };
    };
  } ];
}
