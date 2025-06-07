{ lib, ... }:

{
  options.infra = {
    modules = lib.mkOption {
      type = with lib.types; listOf (submodule {
        options.type = lib.mkOption {
          type = str;
          description = "type of module";
        };
        options.module = lib.mkOption {
          type = raw;
          description = "module";
        };
      });
      description = "define a nixos module";
    };
  };
}
