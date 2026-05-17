{ modules, ... }: {
  infra.nodes.t3 = {
    id = 3;
    address = "t3.ff.ci";
    dns = [ "1.0.0.1" ];
    cryonet.bootstrap = true;

    modules = (modules "nixos") ++ [ ({ modulesPath, config, ... }: {
      # hardware
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.loader = {
        efi.efiSysMountPoint = "/boot/efi";
        grub = {
          efiSupport = true;
          efiInstallAsRemovable = true;
          device = "nodev";
        };
      };
      boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
      boot.initrd.kernelModules = [ "nvme" ];
      fileSystems."/boot/efi" = { device = "/dev/disk/by-uuid/B674-8A3B"; fsType = "vfat"; };
      fileSystems."/" = { device = "/dev/vda3"; fsType = "ext4"; };
      swapDevices = [ {
        device = "/swap";
        size = 8 * 1024;
      } ];
      # config
      networking.firewall.allowedTCPPorts = [
        80 443
      ];
    }) ];
  };
}
