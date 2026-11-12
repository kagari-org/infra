{ withSystem, ... }: {
  infra.modules = [{
    type = "home";
    module = withSystem "x86_64-linux" ({ inputs', ... }: {
      infra.services.sns = {
        config = { ... }: {
          networking.firewall.allowedTCPPorts = [ 3008 ];
          systemd.services.stable-npm = {
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              DynamicUser = true;
              StateDirectory = "stable-npm";
              ExecStart = "${inputs'.stable-npm.packages.default}/bin/stable-npm --addr 127.0.0.1:3002 --db %S/stable-npm/stable-npm.db";
              Restart = "always";
            };
          };
          systemd.services.substituter-api = {
            wantedBy = [ "multi-user.target" ];
            after = [ "stable-npm.service" ];
            requires = [ "stable-npm.service" ];
            serviceConfig = {
              DynamicUser = true;
              StateDirectory = "substituter-api";
              ExecStart = "${inputs'.substituter-api.packages.default}/bin/substituter-api --listen [::]:3008 --allow 127.0.0.1:3002";
              Restart = "always";
            };
          };
        };
      };
    });
  }];
}
