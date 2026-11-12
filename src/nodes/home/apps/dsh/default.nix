{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.dsh-basic-auth = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@dsh.service" ];
      };

      infra.services.dsh = {
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          nix = {
            nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
            registry.p.flake = inputs.nixpkgs;
            extraOptions = ''
              experimental-features = nix-command flakes
            '';
          };

          networking.firewall.allowedTCPPorts = [ 80 ];
          systemd.services.nginx.serviceConfig.LoadCredential = [
            "dsh-basic-auth:${config.sops.secrets.dsh-basic-auth.path}"
          ];
          services.nginx = {
            enable = true;
            virtualHosts.dsh = {
              basicAuthFile = "/run/credentials/nginx.service/dsh-basic-auth";
              locations."/" = {
                proxyPass = "http://127.0.0.1:3080";
                proxyWebsockets = true;
              };
            };
          };

          systemd.services.dsh = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            path = [ pkgs.nix pkgs.git pkgs.bashInteractive ];
            environment.GIT_TERMINAL_PROMPT = "0";
            serviceConfig = {
              StateDirectory = "dsh";
              WorkingDirectory = "/var/lib/dsh";
              Restart = "always";
              RestartSec = "10s";
            };
            script = ''
              if [ ! -d ".git" ]; then
                git clone --branch anillc https://github.com/Anillc/dsh.nix "$STATE_DIRECTORY"
              fi

              exec nix develop -c dsh
            '';
          };
        };
      };
    };
  }];
}
