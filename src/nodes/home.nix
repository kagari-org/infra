{ inputs, modules, ... }: {
  infra.nodes.home = {
    id = 3;
    address = "127.0.0.1";
    sshOpts = [ "-p" "2334" ];
    singbox.enable = true;
    k3s = {
      disks.data-home = {
        path = "/data";
        tags = [ "data-home" ];
        storageReserved = 0;
      };
      extraManifests.data-home-storageclass.content = {
        apiVersion = "storage.k8s.io/v1";
        kind = "StorageClass";
        metadata.name = "data-home-storageclass";
        provisioner = "driver.longhorn.io";
        allowVolumeExpansion = true;
        reclaimPolicy = "Delete";
        volumeBindingMode = "Immediate";
        parameters = {
          numberOfReplicas = "1";
          staleReplicaTimeout = "30";
          fromBackup = "";
          fsType = "ext4";
          dataLocality = "strict-local";
          diskSelector = "data-home";
          unmapMarkSnapChainRemoved = "ignored";
          disableRevisionCounter = "true";
          dataEngine = "v1";
          backupTargetName = "default";
        };
      };
    };

    modules = (modules "nixos") ++ [ ({ modulesPath, ... }: {
      # hardware
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
      boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      boot.kernelModules = [ "kvm-intel" ];
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
