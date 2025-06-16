{ inputs, modules, ... }: {
  infra.nodes.test1 = {
    id = 1;
    address = "test1.kagari.org";
    cryonet.bootstrap = true;
    k3s = {
      server = true;
      endpoint = true;
      disks.vdb1 = {
        path = "/vdb1";
        tags = [ "vdb1" ];
        storageReserved = 0;
      };
      extraManifests.vdb1-storageclass.content = {
        apiVersion = "storage.k8s.io/v1";
        kind = "StorageClass";
        metadata.name = "vdb1-storageclass";
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
          diskSelector = "vdb1";
          unmapMarkSnapChainRemoved = "ignored";
          disableRevisionCounter = "true";
          dataEngine = "v1";
          backupTargetName = "default";
        };
      };
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
      fileSystems."/vdb1" = {
        device = "/dev/vdb1";
        fsType = "ext4";
      };
      swapDevices = [ {
        device = "/swap";
        size = 8 * 1024;
      } ];
    }) ];
  };
}
