{ inputs, modules, ... }: {
  infra.nodes.trunc = {
    id = 4;
    address = "10.11.0.4";
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;

    modules = (modules "nixos") ++ [ ({ config, lib, node, ... }: {
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
      };

      # config
      sops.secrets.trunc-wg = {
        sopsFile = ./secrets.yaml;
        owner = "systemd-network";
        group = "systemd-network";
      };
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
        interfaces = [ "enp3s0" ];
        config = {
          system.stateVersion = "25.05";
          networking.useNetworkd = true;
          networking.nftables.enable = true;
          services.resolved.enable = false;
          networking.firewall = {
            checkReversePath = false;
            trustedInterfaces = [ "enp3s0" ];
          };
          networking.nat = {
            enable = true;
            internalInterfaces = [ "enp3s0" ];
          };
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = 1;
            "net.ipv4.conf.all.rp_filter" = 0;
          };
          systemd.network.networks.enp3s0 = {
            matchConfig.Name = "enp3s0";
            address = [ "192.168.1.1/24" ];
          };
          services.dnsmasq = {
            enable = true;
            resolveLocalQueries = false;
            settings = {
              interface = "enp3s0";
              server = [ "223.5.5.5" ];
              dhcp-range = "192.168.1.2,192.168.1.254,24h";
            };
          };
        };
      };
    }) ];
  };
}
