{ inputs, modules, ... }: {
  infra.nodes.hk = {
    id = 2;
    address = "hk.s.kagari.org";
    dns = [ "1.0.0.1" ];
    cryonet.bootstrap = true;

    modules = (modules "nixos") ++ (modules "hk") ++ [ ({ modulesPath, config, pkgs, ... }: {
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
          4430 # xgram mtproto
          222 # kagi
          2222 # forgejo
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

      services.caddy = {
        enable = true;
        email = "void@anil.lc";
        virtualHosts = {
          "dash.kagari.org".extraConfig = "reverse_proxy monitoring.kn:3000";
          "note.ani.llc".extraConfig = "reverse_proxy trilium.kn:8080";
          "atuin.ani.llc".extraConfig = "reverse_proxy atuin.kn:8888";
          "vw.anil.lc".extraConfig = "reverse_proxy vaultwarden.kn:8222";
          "git.ani.llc".extraConfig = "reverse_proxy forgejo.kn:3000";
          "immich.ani.llc".extraConfig = "reverse_proxy immich.kn:2283";
          "multica.ani.llc".extraConfig = "reverse_proxy multica.kn:3000";
          "llm.ani.llc".extraConfig = "reverse_proxy new-api.kn:3000";
          "sns.ani.llc".extraConfig = "reverse_proxy sns.kn:3008";
          "cache.ani.llc".extraConfig = "reverse_proxy harmonia.kn:5000";
          "nixbot.ani.llc".extraConfig = "reverse_proxy nixbot.kn:80";
          "kankaiz.com".extraConfig = "reverse_proxy kankaiz.kn:80";
          "www.kankaiz.com".extraConfig = "redir https://kankaiz.com{uri} permanent";
          "xgram.ani.llc".extraConfig = ''
            @xgram path_regexp ^/(group-files($|/)|bot)
            handle @xgram {
              reverse_proxy xgram.kn:80
            }
            handle {
              respond 404
            }
          '';
        };
      };

      systemd.services.forgejo-ssh = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.socat ];
        serviceConfig.Restart = "always";
        script = "exec socat TCP-LISTEN:2222,fork,reuseaddr TCP:forgejo.kn:22";
      };

      systemd.services.kagi-ssh = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.socat ];
        serviceConfig.Restart = "always";
        script = "exec socat TCP-LISTEN:222,fork,reuseaddr TCP:kagi.kn:22";
      };

      systemd.services.xgram-mtproto = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.socat ];
        serviceConfig.Restart = "always";
        script = "exec socat TCP-LISTEN:4430,fork,reuseaddr TCP:xgram.kn:4430";
      };
    }) ];
  };
}
