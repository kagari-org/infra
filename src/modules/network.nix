{
  infra.modules = [ {
    tags = [ "nixos" ];
    module = {
      networking.useNetworkd = true;
      networking.nftables.enable = true;
      networking.firewall.checkReversePath = false;
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
      };
    };
  } ];
}
