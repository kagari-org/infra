{ infra.modules = [{
  type = "home";
  module = {
    infra.services.atuin.config = { pkgs, ... }: {
      services.postgresql.package = pkgs.postgresql_18;
      services.atuin = {
        enable = true;
        host = "::";
        openFirewall = true;
      };
    };
  };
}]; }
