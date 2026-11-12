{ modules, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: let
      multica-key = config.sops.secrets.agents-multica-key.path;
      llm-key = config.sops.secrets.agents-llm-key.path;
    in {
      sops.secrets.agents-multica-key = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@agents.service" ];
      };
      sops.secrets.agents-llm-key = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@agents.service" ];
      };

      infra.services.agents = {
        mounts."/run/secrets" = { };
        config = { config, pkgs, ... }: {
          imports = modules "multica";
          nix = {
            nixPath = [ "nixpkgs=${pkgs.path}" ];
            registry.p.to = {
              type = "path";
              path = "${pkgs.path}";
            };
            settings.experimental-features = [ "nix-command" "flakes" ];
          };
          environment.systemPackages = [
            config.services.multica.package.cli
            pkgs.git
            pkgs.gh
            pkgs.jq
            pkgs.ripgrep
            pkgs.curl
            pkgs.omp
          ];
          systemd.tmpfiles.rules = [
            "d /root/.omp/agent 0700 root root -"
            "L+ /root/.omp/agent/models.yml - - - - ${pkgs.writeText "omp-models.yml" ''
              providers:
                llm:
                  baseUrl: https://llm.ani.llc/v1
                  apiKey: "!cat ${llm-key}"
                  api: openai-completions
                  discovery:
                    type: openai-models-list
            ''}"
          ];
          systemd.services.multica = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            path = [ config.services.multica.package.cli pkgs.git pkgs.gh pkgs.omp ];
            serviceConfig.Restart = "always";
            script = ''
              export HOME=/root
              multica config set server_url https://multica.ani.llc
              multica config set app_url https://multica.ani.llc
              cat ${multica-key} | xargs multica login --token
              multica daemon start --foreground
            '';
          };
        };
      };
    };
  }];
}
