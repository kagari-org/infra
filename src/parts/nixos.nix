{ self, inputs, config, lib, withSystem, ... }: let
  cfg = config.infra;
in {
  options.infra.nixos = lib.mkOption {
    type = with lib.types; attrsOf (submodule ({ config, ... }: {
      options.id = lib.mkOption {
        type = number;
        description = "id";
      };
      options.hostname = lib.mkOption {
        type = str;
        description = "hostname";
      };
      options.sshOpts = lib.mkOption {
        type = listOf str;
        description = "sshOpts";
        default = [];
      };
      options.modules = lib.mkOption {
        type = listOf raw;
        description = "modules";
      };
      options.cryonet-bootstrap = lib.mkOption {
        type = bool;
        description = "cryonet bootstrap";
        default = false;
      };
      options.igp-v4 = lib.mkOption {
        type = str;
        description = "igp v4";
        default = "10.11.0.${toString config.id}";
      };
      options.k3s = {
        server = lib.mkOption {
          type = bool;
          description = "server node";
          default = false;
        };
        endpoint = lib.mkOption {
          type = bool;
          description = "endpoint node";
          default = false;
        };
      };
    }));
    description = "nixos definition";
  };
  config.flake = withSystem "x86_64-linux" ({ inputs', system, ... }: {
    nixosConfigurations = cfg.nixos
      |> lib.mapAttrs (name: value: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = value.modules ++ [ ({ pkgs, ... }: {}) ];
        # inherit (value) modules;
        specialArgs = {
          inherit name;
          nixos = value;
        };
      });
    deploy.nodes = cfg.nixos
      |> lib.mapAttrs (name: value: {
        sshUser = "root";
        inherit (value) hostname sshOpts;
        profiles.system.path = inputs'.deploy.lib.activate.nixos self.nixosConfigurations.${name};
      });
  });
}
