{ infra.modules = [{
  type = "home";
  module = { config, lib, nodes, ... }: {
    sops.secrets.grafana-admin = {
      sopsFile = ./secrets.yaml;
      owner = "grafana";
    };

    sops.secrets.grafana-secret-key = {
      sopsFile = ./secrets.yaml;
      owner = "grafana";
    };

    services.prometheus = {
      enable = true;
      port = 3014;
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            { targets = map (n: "${n.igp-v4}:9101") (lib.attrValues nodes); }
          ];
        }
      ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          root_url = "https://dash.kagari.org/";
        };
        security = {
          admin_user = "Anillc";
          admin_password = "$__file{${config.sops.secrets.grafana-admin.path}}";
          secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
        };
        analytics.reporting_enabled = false;
      };
      provision.datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:3014";
          isDefault = true;
        }
      ];
    };
  };
}]; }
