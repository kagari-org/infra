{ infra.modules = [{
  type = "home";
  module = {
    sops.secrets.forgejo-admin-password = {
      sopsFile = ./secrets.yaml;
      owner = "forgejo";
      mode = "0400";
    };

    services.forgejo = {
      enable = true;
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = "git.ani.llc";
          ROOT_URL = "https://git.ani.llc/";
          SSH_DOMAIN = "git.ani.llc";
          SSH_PORT = 2222;
          SSH_LISTEN_HOST = "0.0.0.0";
          SSH_LISTEN_PORT = 2222;
          START_SSH_SERVER = true;
          # 3000 is used by Grafana.
          HTTP_PORT = 3001;
        };
        service.DISABLE_REGISTRATION = true;
        session.COOKIE_SECURE = true;
        metrics.ENABLED = true;
        indexer = {
          ISSUE_INDEXER_TYPE = "bleve";
          REPO_INDEXER_ENABLED = true;
        };
      };
    };
  };
}]; }
