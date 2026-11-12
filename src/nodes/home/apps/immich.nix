{ infra.modules = [{
  type = "home";
  module = {
    infra.services.immich = {
      mounts."/data/immich" = { isReadOnly = false; };
      config = { pkgs, ... }: {
        services.postgresql.package = pkgs.postgresql_18;
        services.immich = {
          enable = true;
          host = "::";
          mediaLocation = "/data/immich";
          openFirewall = true;
          machine-learning.enable = true;
        };
      };
    };
  };
}]; }
