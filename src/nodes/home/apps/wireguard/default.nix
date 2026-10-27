{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.home-wg = {
      sopsFile = ./secrets.yaml;
      owner = "systemd-network";
      group = "systemd-network";
    };
    systemd.network.netdevs.cola = {
      netdevConfig = {
        Name = "cola";
        Kind = "wireguard";
      };
      wireguardConfig.PrivateKeyFile = config.sops.secrets.home-wg.path;
      wireguardPeers = [{
        Endpoint = "cola.s.kagari.org:16804";
        PublicKey = "6fpoIrC842jtIze4YneGNiChE1oSVklsX+NHU2dzPWY=";
        PersistentKeepalive = 25;
        AllowedIPs = [ "0.0.0.0/0" "::/0" ];
      }];
    };
    systemd.network.networks.cola = {
      matchConfig.Name = "cola";
      networkConfig.Address = "fe80::1/64";
    };
  };
}]; }
