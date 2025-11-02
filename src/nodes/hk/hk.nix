{ inputs, modules, ... }: {
  infra.nodes.hk = {
    id = 2;
    address = "hk.s.kagari.org";
    dns = [ "1.0.0.1" ];

    modules = (modules "nixos") ++ [ ({ modulesPath, config, ... }: {
      # hardware
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.loader.grub.device = "/dev/sda";
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/40c6cbfd-fec1-48a3-b4fd-d93c237719ec";
        fsType = "ext4";
      };
      swapDevices = [ {
        device = "/swap";
        size = 8 * 1024;
      } ];
      # config
      networking.firewall = let
        port = config.services.coturn.listening-port;
        range = {
          from = config.services.coturn.min-port;
          to   = config.services.coturn.max-port;
        };
      in {
        allowedUDPPortRanges = [ range ];
        allowedUDPPorts      = [ port ];
        allowedTCPPortRanges = [ range ];
        allowedTCPPorts      = [
          port
          80 443
          445 # samba
        ];
      };
      sops.secrets.coturn-user = {
        sopsFile = ./secrets.yaml;
        owner = "turnserver";
        group = "turnserver";
      };
      systemd.services.coturn.preStart = ''
        cat ${config.sops.secrets.coturn-user.path} >> "/run/coturn/turnserver.cfg"
      '';
      services.coturn = {
        enable = true;
        no-cli = true;
        lt-cred-mech = true;
      };
    }) ];
  };
}
