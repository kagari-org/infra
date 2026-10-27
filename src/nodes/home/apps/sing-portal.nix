{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { lib, nodes, ... }: {
      networking.nftables.tables.nixos-fw.content = lib.mkAfter ''
        chain sing-portal-output {
          type route hook output priority mangle; policy accept;
          socket cgroupv2 level 1 "singportal.slice" ct mark set ${toString nodes.home.singbox.direct}
        }
      '';
      systemd.slices.singportal.wantedBy = [ "nftables.service" ];
      systemd.services.sing-portal = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [ inputs.sing-portal.packages.x86_64-linux.default ];
        script = ''
          exec sing-portal serve \
            --listen 0.0.0.0:3015 \
            --db "$STATE_DIRECTORY/portal.db"
        '';
        serviceConfig = {
          Slice = "singportal.slice";
          StateDirectory = "sing-portal";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
  }];
}
