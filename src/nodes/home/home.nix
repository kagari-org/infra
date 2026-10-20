{ inputs, modules, ... }: {
  infra.nodes.home = {
    id = 3;
    address = "10.11.0.3";
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;

    modules = (modules "nixos") ++ [ ({ modulesPath, config, lib, nodes, ... }: {
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
      # config
      sops.secrets.home-wg = {
        sopsFile = ./secrets.yaml;
        owner = "systemd-network";
        group = "systemd-network";
      };
      systemd.network.netdevs.cola = {
        netdevConfig = {
          Name = "cola";
          Kind = "wireguard";
        };
        wireguardConfig.PrivateKeyFile = config.sops.secrets.home-wg.path;
        wireguardPeers = [{
          Endpoint = "cola.s.kagari.org:16804";
          PublicKey = "6fpoIrC842jtIze4YneGNiChE1oSVklsX+NHU2dzPWY=";
          PersistentKeepalive = 25;
          AllowedIPs = [ "0.0.0.0/0" "::/0" ];
        }];
      };
      systemd.network.networks.cola = {
        matchConfig.Name = "cola";
        networkConfig.Address = "fe80::1/64";
      };

      sops.secrets.grafana-admin = {
        sopsFile = ./secrets.yaml;
        owner = "grafana";
      };

      services.prometheus = {
        enable = true;
        port = 9091;
        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [
              { targets = map (n: "${n.igp-v4}:9101") (lib.attrValues nodes); }
            ];
          }
        ];
      };

      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "0.0.0.0";
            root_url = "https://dash.kagari.org/";
          };
          security = {
            admin_user = "Anillc";
            admin_password = "$__file{${config.sops.secrets.grafana-admin.path}}";
          };
          analytics.reporting_enabled = false;
        };
        provision.datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:9091";
            isDefault = true;
          }
        ];
      };

      services.trilium-server = {
        enable = true;
        host = "0.0.0.0";
      };

      # The old Atuin CNPG is 17.5; unstable defaults to PostgreSQL 18.
      # pg_restore 18 restores the 17 dump forward, and the system bump keeps 18.
      services.postgresql.package =
        inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.postgresql;

      services.atuin = {
        enable = true;
        host = "0.0.0.0";
        package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.atuin;
      };

      # 25.11's module runs `atuin server start`; the newer atuin package splits
      # the server into a separate `atuin-server` binary. Remove after the system bump.
      systemd.services.atuin.serviceConfig.ExecStart =
        lib.mkForce "${lib.getExe' config.services.atuin.package "atuin-server"} start";

      sops.secrets.vaultwarden-admin = {
        sopsFile = ./secrets.yaml;
      };

      services.vaultwarden = {
        enable = true;
        domain = "vw.anil.lc";
        package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.vaultwarden;
        webVaultPackage = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.vaultwarden.webvault;
        environmentFile = config.sops.secrets.vaultwarden-admin.path;
        config = {
          # 8222 matches the current k8s EndpointSlice; drop this and use
          # Vaultwarden's default 8000 after the k8s route is removed.
          ROCKET_PORT = 8222;
          SIGNUPS_ALLOWED = false;
        };
      };

      sops.secrets.forgejo-admin-password = {
        sopsFile = ./secrets.yaml;
        owner = "forgejo";
        mode = "0400";
      };

      services.forgejo = {
        enable = true;
        package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.forgejo-lts;
        lfs.enable = true;
        settings = {
          server = {
            DOMAIN = "git.ani.llc";
            ROOT_URL = "https://git.ani.llc/";
            SSH_DOMAIN = "git.ani.llc";
            SSH_PORT = 2222;
            SSH_LISTEN_HOST = "0.0.0.0";
            SSH_LISTEN_PORT = 2222;
            START_SSH_SERVER = true;
            # 3000 is used by Grafana.
            HTTP_PORT = 3001;
          };
          service.DISABLE_REGISTRATION = true;
          session.COOKIE_SECURE = true;
          metrics.ENABLED = true;
          indexer = {
            ISSUE_INDEXER_TYPE = "bleve";
            REPO_INDEXER_ENABLED = true;
          };
        };
      };

    }) ];
  };
}
