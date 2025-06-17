{ inputs, modules, ... }: {
  infra.nodes.cola = {
    id = 1;
    address = "cola.s.kagari.org";
    sshOpts = [ "-p" "16801" ];
    k3s = {
      server = true;
      endpoint = true;
      disks.data-cola = {
        path = "/data";
        tags = [ "default" "data-cola" ];
        storageReserved = 0;
      };
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
      networking.firewall.allowedTCPPorts = [ 16801 ];
      services.openssh.ports = [ 16801 22 ];
    }) ];
  };
}
