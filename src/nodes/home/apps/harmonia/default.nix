{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.harmonia-sign-key.sopsFile = ./secrets.yaml;

    services.harmonia.cache = {
      enable = true;
      signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];
      settings.bind = "0.0.0.0:3010";
    };
  };
}]; }
