{ modules, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.multica-env = {
        sopsFile = ./secrets.yaml;
        mode = "0400";
        restartUnits = [ "container@multica.service" ];
      };

      infra.services.multica = {
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          imports = modules "multica";
          networking.firewall.allowedTCPPorts = [ 3000 ];
          services.multica = {
            enable = true;
            environmentFile = config.sops.secrets.multica-env.path;
            frontend = {
              listenAddress = "::";
              publicUrl = "https://multica.ani.llc";
            };
            backend.publicUrl = "https://multica.ani.llc";
          };
          services.postgresql = {
            package = pkgs.postgresql_18;
            extensions = ps: [ ps.pgvector ];
          };
        };
      };
    };
  }];
}
