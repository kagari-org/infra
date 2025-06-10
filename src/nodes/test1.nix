{ inputs, modules, ... }: {
  infra.nodes.test1 = {
    id = 1;
    address = "test1.kagari.org";
    cryonet.bootstrap = true;
    k3s = {
      server = true;
      endpoint = true;
    };

    modules = (modules "nixos") ++ [ ({ modulesPath, ... }: {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.loader.grub = {
        enable = true;
        device = "/dev/vda";
      };
      fileSystems."/" = {
        device = "/dev/vda3";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/vda2";
        fsType = "vfat";
      };
      swapDevices = [ {
        device = "/swap";
        size = 8 * 1024;
      } ];
    }) ];
  };
}
