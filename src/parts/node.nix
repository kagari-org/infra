{ self, inputs, config, lib, withSystem, ... }: let
  cfg = config.infra;
in {
  options.infra.nodes = lib.mkOption {
    type = with lib.types; attrsOf (submodule ({ name, config, ... }: {
      options.id = lib.mkOption {
        type = number;
        description = "id";
      };
      options.address = lib.mkOption {
        type = str;
        description = "address";
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
      options.cryonet.bootstrap = lib.mkOption {
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
        enable = lib.mkOption {
          type = bool;
          description = "enable k3s";
          default = true;
        };
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
        zone = lib.mkOption {
          type = str;
          description = "Zone label for node. Node's name by default.";
          default = name;
        };
      };
      options.singbox = {
        enable = lib.mkOption {
          type = bool;
          description = "enable singbox";
          default = false;
        };
        mark = lib.mkOption {
          type = number;
          description = "fwmark";
          default = 233;
        };
        direct = lib.mkOption {
          type = number;
          description = "direct mark";
          default = 234;
        };
        table = lib.mkOption {
          type = number;
          description = "table";
          default = 233;
        };
      };
    }));
    description = "nixos definition";
  };
  config.flake = withSystem "x86_64-linux" ({ inputs', system, ... }: {
    nixosConfigurations = cfg.nodes
      |> lib.mapAttrs (name: node: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        inherit (node) modules;
        specialArgs = {
          inherit name node;
        };
      });
    deploy.nodes = cfg.nodes
      |> lib.mapAttrs (name: value: {
        sshUser = "root";
        hostname = value.address;
        profiles.system.path = inputs'.deploy.lib.activate.nixos self.nixosConfigurations.${name};
        inherit (value) sshOpts;
      });
  });
}
