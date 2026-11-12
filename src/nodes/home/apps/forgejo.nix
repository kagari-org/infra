{ infra.modules = [{
  type = "home";
  module = {
    infra.services.forgejo.config = {
      networking.firewall.allowedTCPPorts = [ 3000 22 ];
      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
      services.forgejo = {
        enable = true;
        lfs.enable = true;
        settings = {
          server = {
            DOMAIN = "git.ani.llc";
            ROOT_URL = "https://git.ani.llc/";
            SSH_DOMAIN = "git.ani.llc";
            SSH_PORT = 2222;
            SSH_LISTEN_HOST = "::";
            SSH_LISTEN_PORT = 22;
            START_SSH_SERVER = true;
            HTTP_ADDR = "::";
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
  };
}]; }
