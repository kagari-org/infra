{ inputs, modules, ... }: {
  infra.nodes.test1 = {
    id = 1;
    address = "test1.kagari.org";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test1" ]);
    cryonet.bootstrap = true;
    k3s = {
      server = true;
      endpoint = true;
    };
  };

  infra.modules = [ {
    tags = [ "nixos:test1" ];
    module = { modulesPath, ... }: {
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
    };
  } ];
}
