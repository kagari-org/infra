{ inputs, ... }: {
  infra.modules = [ {
    tags = [ "nixos:test4" ];
    module = { lib, modulesPath, ... }: {
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
