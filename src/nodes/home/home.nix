{ modules, ... }: {
  infra.nodes.home = {
    id = 3;
    address = "10.11.0.3";
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;

    modules = (modules "nixos") ++ (modules "home") ++ [ ({ modulesPath, ... }: {
      # hardware
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];
      boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      boot.kernelModules = [ "kvm-intel" "br_netfilter" ];
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.swraid = {
        enable = true;
        mdadmConf = ''
          MAILADDR root
          ARRAY /dev/md0 level=raid5 num-devices=3 metadata=1.2 UUID=a3b1c844:9d8d6537:93a2d397:500029e1
             devices=/dev/sda1,/dev/sdb1,/dev/sdc1
        '';
      };
      # br_netfilter sends bridged packets through netfilter twice, which breaks
      # the tproxy path for podman0 (egress and DNS both hang).
      boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" = 0;
      boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" = 0;
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/f1021e42-d516-450d-8f93-34d48205c770";
        fsType = "xfs";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/9D8B-5261";
        fsType = "vfat";
      };
      fileSystems."/data" = {
        device = "/dev/md0";
        fsType = "xfs";
      };
    }) ];
  };
}
