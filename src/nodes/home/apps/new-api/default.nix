{ infra.modules = [{
  type = "home";
  module = { config, ... }: {
    sops.secrets.new-api-env = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
      restartUnits = [ "container@new-api.service" ];
    };

    infra.services.new-api = {
      flags = [ "--system-call-filter=seccomp" "--system-call-filter=bpf" ];
      mounts."/run/secrets" = { };
      config = { pkgs, ... }: {
        networking.firewall.allowedTCPPorts = [ 3000 ];
        services.postgresql = {
          enable = true;
          package = pkgs.postgresql_18;
          authentication = "local newapi newapi peer map=newapi";
          identMap = "newapi root newapi";
          ensureDatabases = [ "newapi" ];
          ensureUsers = [{ name = "newapi"; ensureDBOwnership = true; }];
        };
        systemd.services.podman-new-api = {
          after = [ "postgresql.service" ];
          partOf = [ "postgresql.service" ];
        };
        virtualisation.oci-containers.containers.new-api = {
          image = "docker.io/calciumion/new-api:v1.0.0-rc.49";
          cmd = [ "--log-dir" "/app/logs" ];
          environment = {
            TZ = "Asia/Shanghai";
            ERROR_LOG_ENABLED = "true";
            BATCH_UPDATE_ENABLED = "true";
            NODE_NAME = "new-api-node-1";
            # RELAY_TIMEOUT must stay unset: it is a whole-request timeout and
            # truncates legitimate long streaming responses.
            RELAY_IDLE_CONN_TIMEOUT = "60";
            RELAY_RESPONSE_HEADER_TIMEOUT = "60";
            RELAY_HTTP2_PING_IDLE_TIMEOUT = "30";
            RELAY_HTTP2_PING_TIMEOUT = "15";
          };
          environmentFiles = [ config.sops.secrets.new-api-env.path ];
          extraOptions = [ "--network=host" ];
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
    };
  };
}]; }
