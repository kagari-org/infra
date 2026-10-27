{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.multica-env = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    services.multica = {
      enable = true;
      environmentFile = config.sops.secrets.multica-env.path;
      frontend = {
        listenAddress = "0.0.0.0";
        port = 3004;
        publicUrl = "https://multica.ani.llc";
      };
      backend = {
        port = 3009;
        publicUrl = "https://multica.ani.llc";
      };
      web.remoteApiUrl = "http://127.0.0.1:3009";
    };
  };
}]; }
