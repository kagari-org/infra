{ infra.modules = [{
  type = "home";
  module = { config, pkgs, ... }: {
    sops.secrets.clinal-repo-url = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "clinal.service" ];
    };
    sops.secrets.clinal-env = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "clinal.service" ];
    };
    systemd.services.clinal = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" "nix-daemon.socket" ];
      after = [ "network-online.target" "nix-daemon.socket" "sops-install-secrets.service" ];
      path = [ config.nix.package pkgs.git pkgs.bashInteractive ];
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
}]; }
