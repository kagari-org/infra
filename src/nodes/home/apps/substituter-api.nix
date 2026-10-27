{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = {
      systemd.services.substituter-api = {
        wantedBy = [ "multi-user.target" ];
        after = [ "stable-npm.service" ];
        requires = [ "stable-npm.service" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "substituter-api";
          ExecStart = "${inputs.substituter-api.packages.x86_64-linux.default}/bin/substituter-api --listen 0.0.0.0:3008 --allow 127.0.0.1:3002";
          Restart = "always";
        };
      };
    };
  }];
}
