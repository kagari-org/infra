{ lib, ... }:

{
  options.infra = {
    modules = lib.mkOption {
      type = with lib.types; listOf (submodule {
        options.tags = lib.mkOption {
          type = listOf str;
          description = "tags of module";
        };
        options.module = lib.mkOption {
          type = anything;
          description = "module";
        };
      });
      description = "define a nixos module";
    };
  };
}
