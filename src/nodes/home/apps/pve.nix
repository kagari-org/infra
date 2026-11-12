{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, lib, ... }: {
      infra.services.pve = {
        nixpkgs = inputs.proxmox-nixos.inputs.nixpkgs-stable.outPath;
        devices = [
          "/dev/kvm"
          "/dev/fuse"
          "/dev/vhost-net"
        ];
        flags = [
          "--capability=CAP_NET_ADMIN"
          "--system-call-filter=add_key"
          "--system-call-filter=keyctl"
          "--system-call-filter=bpf"
        ];
        mounts = {
          "/var/lib/vz" = { hostPath = "/data/pve/vz"; isReadOnly = false; };
          "/var/lib/pve-cluster" = { hostPath = "/data/pve/pve-cluster"; isReadOnly = false; };
          "/dev/kvm" = { isReadOnly = false; };
          "/dev/fuse" = { isReadOnly = false; };
          "/dev/net/tun" = { isReadOnly = false; };
          "/dev/vhost-net" = { isReadOnly = false; };
        };
        config = { lib, ... }: {
          imports = [ inputs.proxmox-nixos.nixosModules.proxmox-ve ];
          nixpkgs.hostPlatform = lib.mkForce { system = "x86_64-linux"; };
          nixpkgs.overlays = [ inputs.proxmox-nixos.overlays.x86_64-linux ];

          networking.hostName = "proxmox";
          users.mutableUsers = false;
          users.users.root.hashedPassword = config.users.users.root.hashedPassword;
          services.resolved.enable = lib.mkForce false;

          networking.nftables.enable = true;
          networking.firewall.allowedTCPPorts = [ 8006 2222 2223 ];
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = 1;
            "net.ipv6.conf.all.forwarding" = 1;
            "net.ipv6.conf.all.accept_ra" = 2;
          };

          systemd.network = {
            netdevs = {
              "10-eda1".netdevConfig = { Name = "eda1"; Kind = "bridge"; };
              "11-eda2".netdevConfig = { Name = "eda2"; Kind = "bridge"; };
              "12-eda1-dummy".netdevConfig = { Name = "eda1-dummy"; Kind = "dummy"; };
              "13-eda2-dummy".netdevConfig = { Name = "eda2-dummy"; Kind = "dummy"; };
            };
            networks = {
              "05-pve-lo" = {
                matchConfig.Name = "lo";
                address = [ "10.0.0.1/32" ];
                linkConfig.RequiredForOnline = false;
              };
              "10-eda1" = {
                matchConfig.Name = "eda1";
                address = [ "169.254.1.1/24" "fd00:eda1::1/64" ];
                networkConfig.IPv6SendRA = true;
              };
              "11-eda2" = {
                matchConfig.Name = "eda2";
                address = [ "169.254.2.1/24" "fd00:eda2::1/64" ];
                networkConfig.IPv6SendRA = true;
              };
              "12-eda1-dummy" = {
                matchConfig.Name = "eda1-dummy";
                networkConfig.Bridge = "eda1";
                linkConfig.RequiredForOnline = false;
              };
              "13-eda2-dummy" = {
                matchConfig.Name = "eda2-dummy";
                networkConfig.Bridge = "eda2";
                linkConfig.RequiredForOnline = false;
              };
            };
          };

          services.proxmox-ve = {
            enable = true;
            ipAddress = "10.0.0.1";
            bridges = [ "eda1" "eda2" ];
            openFirewall = false;
          };

          networking.nftables.tables.eda = {
            family = "inet";
            content = ''
              chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                iifname "svc-pve" tcp dport 2222 dnat ip6 to [fd00:eda1::2]:22
                iifname "svc-pve" tcp dport 2223 dnat ip6 to [fd00:eda2::2]:22
              }

              chain forward {
                type filter hook forward priority filter; policy accept;
                ct status dnat accept
                iifname { "eda1", "eda2" } counter drop
              }
            '';
          };
        };
      };
    };
  }];
}
