{ infra.modules = [{
  type = "home";
  module = { config, lib, nodes, ... }: {
    sops.secrets.grafana-admin = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "container@monitoring.service" ];
    };

    sops.secrets.grafana-secret-key = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "container@monitoring.service" ];
    };

    infra.services.monitoring = {
      filter = false;
      mounts."/run/secrets" = { };
      config = {
        networking.firewall.allowedTCPPorts = [ 3000 ];

        services.prometheus = {
          enable = true;
          scrapeConfigs = [
            {
              job_name = "node";
              static_configs = [
                { targets = map (name: "${name}.kn:9101") (lib.attrNames nodes); }
              ];
            }
          ];
        };

        systemd.services.grafana.serviceConfig.LoadCredential = [
          "grafana-admin:${config.sops.secrets.grafana-admin.path}"
          "grafana-secret-key:${config.sops.secrets.grafana-secret-key.path}"
        ];
        services.grafana = {
          enable = true;
          settings = {
            server = {
              http_addr = "::";
              root_url = "https://dash.kagari.org/";
            };
            security = {
              admin_user = "Anillc";
              admin_password = "$__file{/run/credentials/grafana.service/grafana-admin}";
              secret_key = "$__file{/run/credentials/grafana.service/grafana-secret-key}";
            };
            analytics.reporting_enabled = false;
          };
          provision.datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
          ];
        };
      };
    };
  };
}]; }
