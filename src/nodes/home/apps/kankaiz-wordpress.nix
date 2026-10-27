{ infra.modules = [{
  type = "home";
  module = { pkgs, ... }: {
    # PHP in the container runs as www-data (uid 33); MariaDB's unix_socket auth
    # maps the connecting uid back to this account, so no DB password is stored.
    users.groups.www-data.gid = 33;
    users.users.www-data = {
      isSystemUser = true;
      group = "www-data";
      uid = 33;
    };

    systemd.services.mysql.serviceConfig.RuntimeDirectoryPreserve = "restart";
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "wordpress" ];
      ensureUsers = [{
        name = "www-data";
        ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
      }];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/kankaiz-wordpress/html 0755 33 33 -"
    ];
    systemd.services.podman-kankaiz-wordpress = {
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];
    };
    virtualisation.oci-containers.containers.kankaiz-wordpress = let
      phpIni = pkgs.writeText "kankaiz-wordpress-php.ini" ''
        upload_max_filesize = 160M
        post_max_size = 160M
      '';
    in {
      image = "docker.io/library/wordpress:7.1.3-php8.4-apache";
      ports = [ "8083:80" ];
      environment = {
        WORDPRESS_DB_HOST = "localhost:/run/mysqld/mysqld.sock";
        WORDPRESS_DB_NAME = "wordpress";
        WORDPRESS_DB_USER = "www-data";
        WORDPRESS_DB_PASSWORD = "";
      };
      volumes = [
        "/var/lib/kankaiz-wordpress/html:/var/www/html"
        "/run/mysqld:/run/mysqld"
        "${phpIni}:/usr/local/etc/php/conf.d/zz-kankaiz-wordpress.ini:ro"
      ];
    };
  };
}]; }
