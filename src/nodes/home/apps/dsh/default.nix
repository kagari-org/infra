{ infra.modules = [{
  type = "home";
  module = { config, pkgs, ... }: {
    sops.secrets.dsh-basic-auth = {
      sopsFile = ./secrets.yaml;
      owner = "nginx";
      mode = "0400";
      restartUnits = [ "nginx.service" ];
    };

    services.nginx.virtualHosts.dsh = {
      listen = [ { addr = "0.0.0.0"; port = 3016; } ];
      basicAuthFile = config.sops.secrets.dsh-basic-auth.path;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3080";
        proxyWebsockets = true;
      };
    };

    systemd.services.dsh = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" "nix-daemon.socket" ];
      after = [ "network-online.target" "nix-daemon.socket" ];
      path = [ config.nix.package pkgs.git pkgs.bashInteractive ];
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
}]; }
