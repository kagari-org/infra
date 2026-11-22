{ inputs, modules, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.clinal-repo-url = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@clinal.service" ];
      };
      sops.secrets.clinal-env = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@clinal.service" ];
      };
      sops.secrets.clinal-multica-key = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@clinal.service" ];
      };

      infra.services.clinal = {
        allow = [ { domain = "pve.kn"; port = 2222; } ];
        flags = [ "--system-call-filter=seccomp" "--system-call-filter=bpf" ];
        mounts."/run/secrets" = { };
        config = { pkgs, ... }@args: {
          imports = modules "multica";

          environment.systemPackages = [ args.config.services.multica.package.cli ];

          nix = {
            nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
            registry.p.flake = inputs.nixpkgs;
            extraOptions = ''
              experimental-features = nix-command flakes
            '';
          };

          networking.firewall.allowedTCPPorts = [ 80 ];
          boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
          virtualisation.podman.enable = true;

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql_18;
            authentication = "local clinal clinal peer map=clinal";
            identMap = "clinal root clinal";
            ensureDatabases = [ "clinal" ];
            ensureUsers = [{ name = "clinal"; ensureDBOwnership = true; }];
          };

          systemd.services.clinal-multica-login = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            path = [ args.config.services.multica.package.cli pkgs.coreutils pkgs.findutils ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              export HOME=/root
              multica config set server_url https://multica.ani.llc
              multica config set app_url https://multica.ani.llc
              cat ${config.sops.secrets.clinal-multica-key.path} | xargs multica login --token
            '';
          };

          systemd.services.clinal = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" "podman.socket" "postgresql-setup.service" "clinal-multica-login.service" ];
            after = [ "network-online.target" "podman.socket" "postgresql-setup.service" "clinal-multica-login.service" ];
            requires = [ "postgresql-setup.service" ];
            path = [ pkgs.nix pkgs.git pkgs.bashInteractive args.config.services.multica.package.cli ];
            environment = {
              GIT_TERMINAL_PROMPT = "0";
              PORT = "80";
              SELF_URL = "http://clinal.kn";
              CLINAL_DB = "postgres";
              PGHOST = "/run/postgresql";
              HOME = "/root";
            };
            serviceConfig = {
              StateDirectory = "clinal";
              WorkingDirectory = "/var/lib/clinal";
              Restart = "always";
              RestartSec = "10s";
            };
            script = ''
              if [ ! -d ".git" ]; then
                git clone "$(cat ${config.sops.secrets.clinal-repo-url.path})" "$STATE_DIRECTORY"
              fi
              ln -sfn ${config.sops.secrets.clinal-env.path} .env

              exec nix develop -c koishi start
            '';
          };
        };
      };
    };
  }];
}
