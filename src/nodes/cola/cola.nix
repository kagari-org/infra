{ inputs, modules, ... }: {
  infra.nodes.cola = {
    id = 1;
    address = "cola.s.kagari.org";
    sshOpts = [ "-p" "16801" ];
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;
    cryonet.bootstrap = true;
    k3s = {
      server = true;
      endpoint = true;
      disks = [ {
        name = "data-cola";
        path = "/data";
        tags = [ "default" "data-cola" ];
        storageReserved = 0;
      } ];
    };

    modules = (modules "nixos") ++ [ ({ config, lib, ... }: {
      # hardware
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      boot.initrd.availableKernelModules = [ "ata_piix" "ahci" "vmw_pvscsi" "sd_mod" "sr_mod" ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.loader.grub = {
          enable = true;
          efiSupport = true;
          device = "nodev";
      };
      boot.loader.efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot/efi";
      };
      fileSystems."/" = {
          device = "/dev/disk/by-uuid/19a130c5-e0b7-460f-bd7b-c05b0ede5502";
          fsType = "ext4";
      };
      fileSystems."/boot/efi" = {
          device = "/dev/disk/by-uuid/55B0-21D2";
          fsType = "vfat";
      };
      fileSystems."/data" = {
          device = "/dev/disk/by-uuid/c1543fa7-4769-46be-ab17-7adaf8c858f0";
          fsType = "ext4";
      };
      swapDevices = [ {
        device = "/swap";
        size = 8 * 1024;
      } ];
      # config
      networking.hostName = "Anillc-linux";
      virtualisation.vmware.guest = {
          enable = true;
          headless = true;
      };
      services.openssh.ports = [ 16801 22 ];

      networking.firewall.allowedTCPPorts = [
        16801 # ssh
        16807 16808 # mc
        16809 # cryonet bootstrap
      ];
      networking.firewall.allowedUDPPorts = [
        16804 16805 # wireguard
      ];


      sops.secrets.cola-wg = {
        sopsFile = ./secrets.yaml;
        owner = "systemd-network";
        group = "systemd-network";
      };
      systemd.network.netdevs.onekvm = {
        netdevConfig = {
          Name = "onekvm";
          Kind = "wireguard";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets.cola-wg.path;
          ListenPort = 16805;
        };
        wireguardPeers = [{
          PublicKey = "1qnmmXdsF4jUEZbT2N4oELx+pq+iUY5BaVQjT0ETeko=";
          PersistentKeepalive = 25;
          AllowedIPs = [ "0.0.0.0/0" "::/0" ];
        }];
      };
      systemd.network.networks.onekvm = {
        matchConfig.Name = "onekvm";
        networkConfig.Address = "fe80::2/64";
      };

      systemd.network.netdevs.home = {
        netdevConfig = {
          Name = "home";
          Kind = "wireguard";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets.cola-wg.path;
          ListenPort = 16804;
        };
        wireguardPeers = [{
          PublicKey = "DDVb8SfxhNUW+Ja1p8pT5OiGnxpMmvqh86A636+4Aic=";
          PersistentKeepalive = 25;
          AllowedIPs = [ "0.0.0.0/0" "::/0" ];
        }];
      };
      systemd.network.networks.home = {
        matchConfig.Name = "home";
        networkConfig.Address = "fe80::2/64";
      };
    }) ];
  };
}
