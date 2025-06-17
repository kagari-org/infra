{ inputs, modules, ... }: {
  infra.nodes.hk = {
    id = 2;
    address = "hk.s.kagari.org";
    cryonet.bootstrap = true;

    modules = (modules "nixos") ++ [ ({ modulesPath, ... }: {
      # hardware
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.loader.grub.device = "/dev/sda";
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/854d1a98-a604-4e0b-a7c1-aabf104354a1";
        fsType = "ext4";
      };
      swapDevices = [ {
        device = "/dev/disk/by-uuid/f61df665-c769-4419-a3ce-afb8c7aaa44a";
      } ];
      # config
      networking.firewall.allowedTCPPorts = [ 80 443 ];
    }) ];
  };
}
