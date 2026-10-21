{ inputs, modules, ... }: {
  infra.nodes.hk = {
    id = 2;
    address = "hk.s.kagari.org";
    dns = [ "1.0.0.1" ];
    cryonet.bootstrap = true;

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
        allowedUDPPorts      = [
          port
          16807 16808 # factorio
        ];
        allowedTCPPortRanges = [ range ];
        allowedTCPPorts      = [
          port
          80 443
          445 # samba
          2222 # gitea ssh
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

      security.acme = {
        acceptTerms = true;
        defaults.email = "void@anil.lc";
      };

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        appendHttpConfig = ''
          proxy_buffering off;
          client_max_body_size 0;
        '';
        virtualHosts = {
          "dash.kagari.org" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:3000";
          };
          "note.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8080";
          };
          "atuin.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8888";
          };
          "vw.anil.lc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8222";
          };
          "git.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:3001";
          };
          "immich.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:2283";
          };
          "multica.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:3004";
          };
          "llm.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:3005";
          };
          "sns.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8081";
          };
          "cache.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8086";
          };
          "buildbot.ani.llc" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://10.11.0.3:8087";
          };
        };
        streamConfig = ''
          server {
            listen 2222;
            proxy_pass 10.11.0.3:2222;
          }
        '';
      };
    }) ];
  };
}
