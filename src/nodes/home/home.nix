{ inputs, modules, ... }: {
  infra.nodes.home = {
    id = 3;
    address = "10.11.0.3";
    dns = [ "223.5.5.5" "114.114.114.114" ];
    singbox.enable = true;

    modules = (modules "nixos") ++ [ ({ modulesPath, config, lib, nodes, ... }: {
      # hardware
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
        # Temporary: Immich 3.x module from unstable; use the system module after the bump.
        "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/immich.nix"
        inputs.buildbot-nix.nixosModules.buildbot-master
      ];
      # Temporary: keep 25.11's Immich module out of the way; remove after the bump.
      disabledModules = [ "${modulesPath}/services/web-apps/immich.nix" ];
      # Temporary: 25.11's manual rejects the unstable Immich anchors; re-enable after the bump.
      documentation.nixos.enable = false;
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

      sops.secrets.multica-env = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
      };

      sops.secrets.new-api-env = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
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
      # Temporary: drop this after the bump so the system package is used.
      services.postgresql.package =
        inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.postgresql;

      services.atuin = {
        enable = true;
        host = "0.0.0.0";
        # Temporary: atuin from unstable; remove after the bump.
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
        # Temporary: vaultwarden + web vault from unstable; remove after the bump.
        package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.vaultwarden;
        webVaultPackage = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.vaultwarden.webvault;
        environmentFile = config.sops.secrets.vaultwarden-admin.path;
        config = {
          # 8222 matches the current k8s EndpointSlice; drop this and use
          # Vaultwarden's default 8000 after the k8s route is removed.
          ROCKET_PORT = 8222;
          ROCKET_ADDRESS = "0.0.0.0";
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
        # Temporary: Forgejo LTS from unstable; remove after the bump.
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

      services.immich = {
        enable = true;
        host = "";
        # Temporary: Immich from unstable; remove after the bump.
        package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.immich;
        mediaLocation = "/data/immich";
        machine-learning.enable = true;
      };

      services.multica = {
        enable = true;
        environmentFile = config.sops.secrets.multica-env.path;
        frontend = {
          listenAddress = "0.0.0.0";
          port = 3004;
          publicUrl = "https://multica.ani.llc";
        };
        backend = {
          port = 8082;
          publicUrl = "https://multica.ani.llc";
        };
        web.remoteApiUrl = "http://127.0.0.1:8082";
      };

      services.postgresql = {
        authentication = "local newapi newapi peer map=newapi";
        identMap = "newapi root newapi";
        ensureDatabases = [ "newapi" ];
        ensureUsers = [{ name = "newapi"; ensureDBOwnership = true; }];
      };

      networking.nftables.tables.podman-egress = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority -50; policy accept;
            iifname "podman0" ct state established,related accept
            iifname "podman0" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.88.99.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4 } drop
          }
        '';
      };

      systemd.services.podman-new-api.after = [ "postgresql.service" ];
      virtualisation.oci-containers.containers.new-api = {
        image = "docker.io/calciumion/new-api:v0.13.2";
        cmd = [ "--log-dir" "/app/logs" ];
        environment = {
          TZ = "Asia/Shanghai";
          ERROR_LOG_ENABLED = "true";
          BATCH_UPDATE_ENABLED = "true";
          NODE_NAME = "new-api-node-1";
        };
        environmentFiles = [ config.sops.secrets.new-api-env.path ];
        ports = [ "3005:3000" ];
        volumes = [
          "/var/lib/new-api/data:/data"
          "/var/lib/new-api/logs:/app/logs"
          "/run/postgresql:/run/postgresql"
        ];
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/new-api/data 0755 root root -"
        "d /var/lib/new-api/logs 0755 root root -"
      ];

      sops.secrets.agents-multica-key.sopsFile = ./secrets.yaml;

      containers.agents = {
        autoStart = true;
        bindMounts."/run/secrets" = {};
        config = { pkgs, ... }: let
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        in {
          system.stateVersion = "25.11";
          networking.hostName = "agents";
          nix = {
            nixPath = [ "nixpkgs=${pkgs.path}" ];
            registry.p.to = {
              type = "path";
              path = "${pkgs.path}";
            };
            settings.experimental-features = [ "nix-command" "flakes" ];
          };
          environment.systemPackages = [
            unstable.multica-cli
            pkgs.git
            pkgs.gh
            pkgs.jq
            pkgs.ripgrep
            pkgs.curl
          ];
          systemd.services.multica = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            path = [ unstable.multica-cli pkgs.git pkgs.gh ];
            serviceConfig.Restart = "always";
            script = ''
              export HOME=/root
              multica config set server_url https://multica.ani.llc
              multica config set app_url https://multica.ani.llc
              cat ${config.sops.secrets.agents-multica-key.path} | xargs multica login --token
              multica daemon start --foreground
            '';
          };
        };
      };

      sops.secrets.harmonia-sign-key.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-app-secret-key.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-oauth-secret.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-webhook-secret.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-worker-password.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-workers.sopsFile = ./secrets.yaml;

      services.harmonia = {
        enable = true;
        signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];
        settings.bind = "0.0.0.0:8086";
      };

      services.nginx.defaultHTTPListenPort = 8087;

      services.buildbot-nix.master = {
        enable = true;
        domain = "buildbot.ani.llc";
        useHTTPS = true;
        outputsPath = "/var/www/buildbot/nix-outputs/";
        workersFile = config.sops.secrets.buildbot-workers.path;
        admins = [ "Anillc" "Emin017" ];
        github = {
          appId = 4115237;
          appSecretKeyFile = config.sops.secrets.buildbot-app-secret-key.path;
          oauthId = "Iv23ligVsrNcpEqbzl21";
          oauthSecretFile = config.sops.secrets.buildbot-oauth-secret.path;
          webhookSecretFile = config.sops.secrets.buildbot-webhook-secret.path;
          topic = "buildbot-nix";
          userAllowlist = [ "Anillc" "kagari-org" "openecos-projects" ];
        };
      };

      containers.builder = {
        autoStart = true;
        bindMounts."/run/secrets" = {};
        config = { pkgs, ... }: {
          imports = [ inputs.buildbot-nix.nixosModules.buildbot-worker ];
          system.stateVersion = "25.11";
          networking.hostName = "builder";
          nix = {
            nixPath = [ "nixpkgs=${pkgs.path}" ];
            registry.p.to = {
              type = "path";
              path = "${pkgs.path}";
            };
            settings.experimental-features = [ "nix-command" "flakes" ];
          };
          services.buildbot-nix.worker = {
            enable = true;
            name = "forge";
            workerPasswordFile = config.sops.secrets.buildbot-worker-password.path;
          };
        };
      };

      systemd.services.stable-npm = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "stable-npm";
          ExecStart = "${inputs.stable-npm.packages.x86_64-linux.default}/bin/stable-npm --addr 127.0.0.1:3002 --db %S/stable-npm/stable-npm.db";
          Restart = "always";
        };
      };

      systemd.services.substituter-api = {
        wantedBy = [ "multi-user.target" ];
        after = [ "stable-npm.service" ];
        requires = [ "stable-npm.service" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "substituter-api";
          ExecStart = "${inputs.substituter-api.packages.x86_64-linux.default}/bin/substituter-api --listen 0.0.0.0:8081 --allow 127.0.0.1:3002";
          Restart = "always";
        };
      };

    }) ];
  };
}
