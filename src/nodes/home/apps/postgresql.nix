{ infra.modules = [{
  type = "home";
  module = { pkgs, ... }: {
    services.postgresql.package = pkgs.postgresql_18;
  };
}]; }
