{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, lib, pkgs, ... }: {
      imports = [ inputs.buildbot-nix.nixosModules.buildbot-master ];

      sops.secrets.buildbot-app-secret-key.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-oauth-secret.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-webhook-secret.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-worker-password.sopsFile = ./secrets.yaml;
      sops.secrets.buildbot-workers.sopsFile = ./secrets.yaml;

      services.nginx.virtualHosts."buildbot.ani.llc".listen = [ { addr = "0.0.0.0"; port = 3011; } ];

      # TODO: remove once upstream passes makeWrapperArgs as separate arguments.
      # buildbot-nix ships "--prefix PATH : ..." as one list element, which
      # structured attrs no longer word-split.
      services.buildbot-nix.packages.buildbot-effects =
        (pkgs.python3.pkgs.callPackage "${inputs.buildbot-nix.outPath}/packages/buildbot-effects.nix" { })
        .overrideAttrs (_: {
          makeWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ pkgs.bubblewrap ]) ];
        });

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
        config = { pkgs, lib, ... }: {
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
          services.buildbot-nix = {
            # TODO: remove once upstream passes makeWrapperArgs as separate arguments.
            # buildbot-nix ships "--prefix PATH : ..." as one list element, which
            # structured attrs no longer word-split.
            packages.buildbot-effects =
              (pkgs.python3.pkgs.callPackage "${inputs.buildbot-nix.outPath}/packages/buildbot-effects.nix" { })
              .overrideAttrs (_: {
                makeWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ pkgs.bubblewrap ]) ];
              });
            worker = {
              enable = true;
              name = "forge";
              workerPasswordFile = config.sops.secrets.buildbot-worker-password.path;
            };
          };
        };
      };
    };
  }];
}
