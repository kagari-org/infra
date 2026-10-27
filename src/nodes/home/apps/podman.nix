{ infra.modules = [{
  type = "home";
  module = {
    networking.nftables.tables.podman-egress = {
      family = "inet";
      content = ''
        chain forward {
          type filter hook forward priority -50; policy accept;
          iifname "podman0" ct state established,related accept
          iifname "podman0" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.88.99.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4 } drop
        }
      '';
    };
  };
}]; }
