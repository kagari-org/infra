{ inputs, modules, ... }: {
  infra.nodes.test4 = {
    id = 4;
    address = "test4.kagari.org";
    singbox.enable = true;

    modules = (modules "nixos") ++ [ ({ lib, modulesPath, ... }: {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      nix.settings.substituters = lib.mkBefore [ "https://mirrors.sjtug.sjtu.edu.cn/nix-channels/store" ];
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
    }) ];
  };
}
