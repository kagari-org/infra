{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.vaultwarden-admin = {
      sopsFile = ./secrets.yaml;
    };

    services.vaultwarden = {
      enable = true;
      domain = "vw.anil.lc";
      environmentFile = config.sops.secrets.vaultwarden-admin.path;
      config = {
        ROCKET_PORT = 3013;
        ROCKET_ADDRESS = "0.0.0.0";
        SIGNUPS_ALLOWED = false;
      };
    };
  };
}]; }
