{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.harmonia-sign-key = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "container@harmonia.service" ];
    };

    infra.services.harmonia = {
      mounts."/run/secrets" = { };
      config = {
        networking.firewall.allowedTCPPorts = [ 5000 ];
        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];
        };
      };
    };
  };
}]; }
