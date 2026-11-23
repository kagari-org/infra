{ infra.modules = [{
  type = "home";
  module = {
    infra.services.shtu = {
      config = { pkgs, ... }: let
        zju-connect = pkgs.buildGoModule {
          name = "zju-connect";
          vendorHash = "sha256-nb6QOhFDj3ula+hQIF2YSQC25iiS66wDMNz9MdBpiD8=";
          src = pkgs.fetchFromGitHub {
            owner = "Mythologyli";
            repo = "zju-connect";
            rev = "4031c52214478d4082189b778ffc6e9744f1d256";
            hash = "sha256-8jIGwMd4HD2EYCDYW7CN/vogaWUucAIDCYNesjSEA7Y=";
          };
        };
      in {
        networking.firewall.allowedTCPPorts = [ 1080 1081 ];
        systemd.services.zju-connect = {
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ zju-connect ];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
            StateDirectory = "zju-connect";
            WorkingDirectory = "/var/lib/zju-connect";
          };
          script = ''
            zju-connect -config ${(pkgs.formats.toml {}).generate "config.toml" {
              protocol = "atrust";
              server_address = "vpn.shanghaitech.edu.cn";
              auth_type = "auth/cas";
              login_domain = "Shanghaitech.edu.cn";
              client_data_file = "client_data.json";
            }}
          '';
        };
      };
    };
  };
}]; }
