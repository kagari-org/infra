{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.new-api-env = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };

    services.postgresql = {
      authentication = "local newapi newapi peer map=newapi";
      identMap = "newapi root newapi";
      ensureDatabases = [ "newapi" ];
      ensureUsers = [{ name = "newapi"; ensureDBOwnership = true; }];
    };

    systemd.services.podman-new-api.after = [ "postgresql.service" ];
    virtualisation.oci-containers.containers.new-api = {
      image = "docker.io/calciumion/new-api:v0.13.2";
      cmd = [ "--log-dir" "/app/logs" ];
      environment = {
        TZ = "Asia/Shanghai";
        ERROR_LOG_ENABLED = "true";
        BATCH_UPDATE_ENABLED = "true";
        NODE_NAME = "new-api-node-1";
      };
      environmentFiles = [ config.sops.secrets.new-api-env.path ];
      ports = [ "3005:3000" ];
      volumes = [
        "/var/lib/new-api/data:/data"
        "/var/lib/new-api/logs:/app/logs"
        "/run/postgresql:/run/postgresql"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/new-api/data 0755 root root -"
      "d /var/lib/new-api/logs 0755 root root -"
    ];
  };
}]; }
