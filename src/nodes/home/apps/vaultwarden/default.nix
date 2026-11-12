{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.vaultwarden-admin = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "container@vaultwarden.service" ];
    };

    infra.services.vaultwarden = {
      mounts."/run/secrets" = { };
      config = {
        networking.firewall.allowedTCPPorts = [ 8222 ];
        services.vaultwarden = {
          enable = true;
          domain = "vw.anil.lc";
          environmentFile = config.sops.secrets.vaultwarden-admin.path;
          config = {
            ROCKET_ADDRESS = "::";
            ROCKET_PORT = 8222;
            SIGNUPS_ALLOWED = false;
          };
        };
      };
    };
  };
}]; }
