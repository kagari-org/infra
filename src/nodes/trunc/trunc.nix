{ inputs, modules, ... }: {
  infra.nodes.trunc = {
    id = 4;
    address = "10.11.0.4";
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;

    modules = (modules "nixos") ++ [ ({ config, pkgs, lib, node, ... }: {
      # hardware
      boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod" ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.loader.grub = {
        enable = true;
        device = "/dev/sda";
      };
      fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
      };
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      networking.useDHCP = false;
      systemd.network.networks.enp1s0 = {
        matchConfig.Name = "enp1s0";
        DHCP = "ipv4";
        dhcpV4Config.UseDNS = false;
        ipv6AcceptRAConfig.UseDNS = false;
      };

      # config
      sops.secrets.trunc-wg = {
        sopsFile = ./secrets.yaml;
        owner = "systemd-network";
        group = "systemd-network";
      };
      services.resolved.settings.Resolve.DNSStubListenerExtra = [ "10.192.0.1" ];
      networking.firewall.trustedInterfaces = [ "ve-access" ];
      networking.nftables.tables.nixos-fw.content = lib.mkAfter ''
        chain access-masquerade {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "ve-access" masquerade
        }
      '';
      containers.access = {
        autoStart = true;
        privateNetwork = true;
        localAddress = "10.192.0.2";
        hostAddress = "10.192.0.1";
        localAddress6 = "fd00:1::2";
        hostAddress6 = "fd00:1::1";
        interfaces = [ "enp3s0" ];
        config = {
          system.stateVersion = "25.05";
          networking.useNetworkd = true;
          networking.nftables.enable = true;
          services.resolved.enable = false;
          networking.resolvconf.enable = false;
          environment.etc."resolv.conf".text = ''
            nameserver 10.192.0.1
            search kn
          '';
          networking.firewall = {
            checkReversePath = false;
            trustedInterfaces = [ "enp3s0" ];
          };
          networking.nat = {
            enable = true;
            enableIPv6 = true;
            internalInterfaces = [ "enp3s0" ];
          };
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = 1;
            "net.ipv4.conf.all.rp_filter" = 0;
          };
          systemd.network.networks.enp3s0 = {
            matchConfig.Name = "enp3s0";
            address = [ "192.168.1.1/24" "fd00::1/64" ];
          };
          systemd.network.networks."40-eth0".routes = [
            {
              Destination = "0.0.0.0/0";
              Gateway = "10.192.0.1";
              GatewayOnLink = true;
            }
            {
              Destination = "::/0";
              Gateway = "fd00:1::1";
              GatewayOnLink = true;
            }
          ];
          services.dnsmasq = {
            enable = true;
            resolveLocalQueries = false;
            settings = {
              interface = "enp3s0";
              enable-ra = true;
              dhcp-option = [ "option:domain-search,kn" "option6:domain-search,kn" ];
              dhcp-range = [
                "192.168.1.2,192.168.1.254,24h"
                "fd00::,ra-stateless"
              ];
              server = [
                "/kn/10.192.0.1#15353"
                "/11.10.in-addr.arpa/10.192.0.1#15353"
                "/1.1.d.f.ip6.arpa/10.192.0.1#15353"
                "223.5.5.5"
              ];

              enable-tftp = true;
              tftp-root = "${pkgs.ipxe}";
              dhcp-userclass = "set:ipxe,iPXE";
              dhcp-boot = [
                "tag:!ipxe,ipxe.efi"
                "tag:ipxe,https://boot.netboot.xyz"
              ];
            };
          };
        };
      };
    }) ];
  };
}
