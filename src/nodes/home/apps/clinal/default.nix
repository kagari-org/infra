{ inputs, ... }: {
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

      infra.services.clinal = {
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          nix = {
            nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
            registry.p.flake = inputs.nixpkgs;
            extraOptions = ''
              experimental-features = nix-command flakes
            '';
          };

          systemd.services.clinal = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            path = [ pkgs.nix pkgs.git pkgs.bashInteractive ];
            environment.GIT_TERMINAL_PROMPT = "0";
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
