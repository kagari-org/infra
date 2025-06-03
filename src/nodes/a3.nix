{ inputs, modules, ... }: {
  infra.nodes.a3 = {
    id = 3;
    address = "a3.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:a3" ]);
    cryonet.bootstrap = true;
    k3s.server = true;
  };

  infra.modules = [ {
    tags = [ "nixos:a3" ];
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
