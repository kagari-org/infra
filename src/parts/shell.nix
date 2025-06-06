{
  perSystem = { lib, ... }: {
    options.infra.hooks = lib.mkOption {
      type = with lib.types; lines;
      description = "hooks";
    };
  };
}
