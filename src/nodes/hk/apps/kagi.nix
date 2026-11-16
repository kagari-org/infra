{ withSystem, ... }: {
  infra.modules = [{
    type = "hk";
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, ... }: {
      infra.services.kagi = {
        filter = false;
        config = { pkgs, ... }: {
          boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
          networking.firewall.enable = false;

          environment.etc."kagi/kagi.toml".source = (pkgs.formats.toml {}).generate "kagi.toml" {
            server.host_key = "/var/lib/kagi/host_ed25519";
            server.allow_remote_forward = true;
            users.guest.skip_key_check = true;
            users."anillc|root" = {
              match = "regex";
              keys = config.users.users.root.openssh.authorizedKeys.keys;
              admin = true;
              stream_buffer_bytes = 512 * 1024 * 1024;
              rules = [
                { action = "allow"; cidr = "0.0.0.0/0"; port = "*"; }
                { action = "allow"; cidr = "::/0"; port = "*"; }
                { action = "allow"; forward = "listen"; host = "127.0.0.1"; port = "*"; }
                { action = "allow"; forward = "listen"; host = "::1"; port = "*"; }
              ];
            };
          };

          systemd.services.kagi = {
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              DynamicUser = true;
              StateDirectory = "kagi";
              ExecStart = "${inputs'.kagi.packages.default}/bin/kagi serve -c /etc/kagi/kagi.toml";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        };
      };
    });
  }];
}
