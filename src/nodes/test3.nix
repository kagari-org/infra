{ inputs, modules, ... }: {
  infra.nodes.test3 = {
    id = 3;
    address = "test3.kagari.org";
    cryonet.bootstrap = true;
    k3s.server = true;

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
