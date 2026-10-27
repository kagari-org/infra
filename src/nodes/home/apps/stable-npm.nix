{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = {
      systemd.services.stable-npm = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "stable-npm";
          ExecStart = "${inputs.stable-npm.packages.x86_64-linux.default}/bin/stable-npm --addr 127.0.0.1:3002 --db %S/stable-npm/stable-npm.db";
          Restart = "always";
        };
      };
    };
  }];
}
