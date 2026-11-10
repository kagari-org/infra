{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, lib, node, ... }: {
      networking.nftables.tables.pve = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            iifname "cn0" tcp dport 8006 dnat to 10.193.0.2:8006
            iifname "cn0" tcp dport 12222 dnat to 10.193.0.2:2222
            iifname "cn0" tcp dport 12223 dnat to 10.193.0.2:2223
          }

          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            iifname "ve-pve" masquerade
          }

          chain forward {
            type filter hook forward priority -50; policy accept;
            iifname "ve-pve" ct state established,related accept
            iifname "ve-pve" ip daddr {
              0.0.0.0/8,
              10.0.0.0/8,
              100.64.0.0/10,
              127.0.0.0/8,
              169.254.0.0/16,
              172.16.0.0/12,
              192.0.0.0/24,
              192.0.2.0/24,
              192.88.99.0/24,
              192.168.0.0/16,
              198.18.0.0/15,
              198.51.100.0/24,
              203.0.113.0/24,
              224.0.0.0/4,
              240.0.0.0/4,
            } drop
          }

          chain input {
            type filter hook input priority -50; policy accept;
            iifname "ve-pve" meta mark ${toString node.singbox.mark} accept
            iifname "ve-pve" ip daddr 10.193.0.1 udp dport 53 accept
            iifname "ve-pve" ip daddr 10.193.0.1 tcp dport 53 accept
            iifname "ve-pve" drop
          }
        '';
      };

      services.resolved.settings.Resolve.DNSStubListenerExtra = [ "10.193.0.1" ];
      networking.firewall.interfaces."ve-pve" = {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };

      containers.pve = {
        autoStart = true;
        privateNetwork = true;
        nixpkgs = inputs.proxmox-nixos.inputs.nixpkgs-stable.outPath;
        hostAddress = "10.193.0.1";
        localAddress = "10.193.0.2";
        bindMounts = {
          "/var/lib/vz" = { hostPath = "/data/pve/vz"; isReadOnly = false; };
          "/var/lib/pve-cluster" = { hostPath = "/data/pve/pve-cluster"; isReadOnly = false; };
          "/dev/kvm" = { isReadOnly = false; };
          "/dev/fuse" = { isReadOnly = false; };
          "/dev/net/tun" = { isReadOnly = false; };
        };
        allowedDevices = [
          { node = "/dev/kvm"; modifier = "rwm"; }
          { node = "/dev/fuse"; modifier = "rwm"; }
          { node = "/dev/net/tun"; modifier = "rwm"; }
          { node = "/dev/vhost-net"; modifier = "rwm"; }
        ];
        extraFlags = [
          "--capability=CAP_NET_ADMIN"
          "--system-call-filter=add_key"
          "--system-call-filter=keyctl"
          "--system-call-filter=bpf"
        ];
        config = { lib, ... }: {
          imports = [ inputs.proxmox-nixos.nixosModules.proxmox-ve ];
          nixpkgs.hostPlatform = lib.mkForce { system = "x86_64-linux"; };
          nixpkgs.overlays = [ inputs.proxmox-nixos.overlays.x86_64-linux ];

          system.stateVersion = "25.11";
          networking.hostName = "proxmox";
          users.mutableUsers = false;
          users.users.root.hashedPassword = config.users.users.root.hashedPassword;
          services.resolved.enable = lib.mkForce false;
          networking.resolvconf.enable = false;
          environment.etc."resolv.conf".text = ''
            nameserver 10.193.0.1
            search kn
          '';
          networking.useNetworkd = true;
          networking.nftables.enable = true;
          networking.firewall.allowedTCPPorts = [ 8006 ];
          boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

          systemd.network = {
            netdevs = {
              "10-eda1".netdevConfig = { Name = "eda1"; Kind = "bridge"; };
              "11-eda2".netdevConfig = { Name = "eda2"; Kind = "bridge"; };
              "12-eda1-dummy".netdevConfig = { Name = "eda1-dummy"; Kind = "dummy"; };
              "13-eda2-dummy".netdevConfig = { Name = "eda2-dummy"; Kind = "dummy"; };
            };
            networks = {
              "10-eda1" = {
                matchConfig.Name = "eda1";
                address = [ "169.254.1.1/24" ];
              };
              "11-eda2" = {
                matchConfig.Name = "eda2";
                address = [ "169.254.2.1/24" ];
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
              "40-eth0".routes = [
                {
                  Gateway = "10.193.0.1";
                  GatewayOnLink = true;
                }
              ];
            };
          };

          services.proxmox-ve = {
            enable = true;
            ipAddress = "10.193.0.2";
            bridges = [ "eda1" "eda2" ];
          };

          networking.nftables.tables = {
            eda = {
              family = "ip";
              content = ''
                chain prerouting {
                  type nat hook prerouting priority dstnat; policy accept;
                  iifname "eth0" tcp dport 2222 dnat to 169.254.1.2:22
                  iifname "eth0" tcp dport 2223 dnat to 169.254.2.2:22
                }

                chain forward {
                  type filter hook forward priority filter; policy accept;
                  ct status dnat accept
                  iifname { "eda1", "eda2" } counter drop
                }
              '';
            };

            eda-guard6 = {
              family = "ip6";
              content = ''
                chain forward {
                  type filter hook forward priority filter; policy accept;
                  iifname { "eda1", "eda2" } counter drop
                }
              '';
            };
          };
        };
      };
    };
  }];
}
