{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.nixbot-app-secret-key = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@nixbot.service" ];
      };
      sops.secrets.nixbot-oauth-secret = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@nixbot.service" ];
      };
      sops.secrets.nixbot-webhook-secret = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@nixbot.service" ];
      };

      infra.services.nixbot = {
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          imports = [ inputs.nixbot.nixosModules.nixbot ];

          networking.firewall.allowedTCPPorts = [ 80 ];

          # https://github.com/NixOS/nix/blob/3a687eeb4f64c3f9266b2c0b12d8993c72541aed/src/libutil/linux/linux-namespaces.cc#L64
          systemd.services.mount-proc = {
            wantedBy = [ "multi-user.target" ];
            before = [ "nixbot.service" ];
            path = [ pkgs.util-linux ];
            serviceConfig.Type = "oneshot";
            script = "mount -t proc proc /proc";
          };

          services.nixbot = {
            enable = true;
            domain = "nixbot.ani.llc";
            useHTTPS = true;
            outputsPath = "/var/www/nixbot/nix-outputs/";
            admins = [ "github:Anillc" "github:Emin017" ];
            github = {
              enable = true;
              appId = 4115237;
              appSecretKeyFile = config.sops.secrets.nixbot-app-secret-key.path;
              oauthId = "Iv23ligVsrNcpEqbzl21";
              oauthSecretFile = config.sops.secrets.nixbot-oauth-secret.path;
              webhookSecretFile = config.sops.secrets.nixbot-webhook-secret.path;
              topic = "buildbot-nix";
              userAllowlist = [ "Anillc" "kagari-org" "openecos-projects" ];
            };
          };
        };
      };
    };
  }];
}
