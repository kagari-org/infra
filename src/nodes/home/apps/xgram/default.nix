{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.xgram-env = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@xgram.service" ];
      };

      infra.services.xgram = {
        filter = false;
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          nix = {
            nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
            registry.p.flake = inputs.nixpkgs;
            extraOptions = ''
              experimental-features = nix-command flakes
            '';
          };

          networking.firewall.allowedTCPPorts = [ 80 4430 ];
          boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql_18;
            authentication = "local crossgram crossgram peer map=crossgram";
            identMap = "crossgram root crossgram";
            ensureDatabases = [ "crossgram" ];
            ensureUsers = [{ name = "crossgram"; ensureDBOwnership = true; }];
          };

          systemd.services.xgram = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" "postgresql-setup.service" ];
            requires = [ "postgresql-setup.service" ];
            path = [ pkgs.nix pkgs.git pkgs.bashInteractive ];
            environment = {
              GIT_TERMINAL_PROMPT = "0";
              CROSSGRAM_PUBLIC_BASE_URL = "https://xgram.ani.llc";
              CROSSGRAM_POSTGRES_HOST = "/run/postgresql";
            };
            serviceConfig = {
              StateDirectory = "xgram";
              WorkingDirectory = "/var/lib/xgram";
              EnvironmentFile = config.sops.secrets.xgram-env.path;
              Restart = "always";
              RestartSec = "10s";
            };
            script = ''
              if [ ! -d ".git" ]; then
                git clone https://github.com/Anillc/xgram "$STATE_DIRECTORY"
              fi

              exec nix develop -c xgram start
            '';
          };
        };
      };
    };
  }];
}
