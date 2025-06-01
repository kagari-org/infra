{ self, inputs, config, lib, withSystem, ... }: let
  cfg = config.infra;
in {
  options.infra.nixos = lib.mkOption {
    type = with lib.types; attrsOf (submodule {
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
        type = listOf anything;
        description = "modules";
      };
    });
    description = "nixos definition";
  };
  config.flake = withSystem "x86_64-linux" ({ inputs', system, ... }: {
    nixosConfigurations = cfg.nixos
      |> lib.mapAttrs (name: value: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        inherit (value) modules;
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
