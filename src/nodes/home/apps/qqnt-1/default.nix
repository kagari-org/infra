{ inputs, ... }: {
  infra.modules = [{
    type = "home";
    module = { config, ... }: {
      sops.secrets.qqnt-1-env = {
        sopsFile = ./secrets.yaml;
        restartUnits = [ "container@qqnt-1.service" ];
      };

      infra.services.qqnt-1 = {
        mounts."/run/secrets" = { };
        config = { pkgs, ... }: {
          networking.firewall.allowedTCPPorts = [ 18767 80 ];
          boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
          # https://github.com/NixOS/nix/blob/3a687eeb4f64c3f9266b2c0b12d8993c72541aed/src/libutil/linux/linux-namespaces.cc#L64
          systemd.services.mount-proc = {
            wantedBy = [ "multi-user.target" ];
            before = [ "qqnt.service" ];
            path = [ pkgs.util-linux ];
            serviceConfig.Type = "oneshot";
            script = "mount -t proc proc /proc";
          };
          systemd.services.qqnt = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              StateDirectory = "qqnt";
              LoadCredential = [ "qqnt-bridge-env:${config.sops.secrets.qqnt-1-env.path}" ];
              ExecStartPre = "${pkgs.coreutils}/bin/install -Dm 0600 /run/credentials/qqnt.service/qqnt-bridge-env /var/lib/qqnt/qqnt-bridge.env";
              ExecStart = "${inputs.crossgram-qqnt.packages.x86_64-linux.qqnt}/bin/qqnt /var/lib/qqnt 99 5900 80 \"\" qqnt-bridge.env";
              Restart = "always";
              RestartSec = 3;
              KillMode = "control-group";
              TimeoutStopSec = 10;
            };
          };
        };
      };
    };
  }];
}
