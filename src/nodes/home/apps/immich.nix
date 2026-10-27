{ infra.modules = [{
  type = "home";
  module = {
    services.immich = {
      enable = true;
      host = "";
      port = 3006;
      mediaLocation = "/data/immich";
      machine-learning.enable = true;
    };
  };
}]; }
