{ config, lib, ... }: let
  listFiles = path: let
    files = builtins.readDir path;
    regular = files
      |> lib.filterAttrs (_: value: value == "regular")
      |> lib.attrNames
      |> lib.filter (name: lib.strings.hasSuffix ".nix" name && !(lib.strings.hasPrefix "_" name))
      |> map (x: /${path}/${x});
    directory = files
      |> lib.filterAttrs (name: value: value == "directory" && !(lib.strings.hasPrefix "_" name))
      |> lib.attrNames
      |> map (x: listFiles /${path}/${x})
      |> lib.flatten;
  in regular ++ directory;
in {
  imports = listFiles ./.;
  _module.args.modules = type: config.infra.modules
    |> lib.filter (module: module.type == type)
    |> map ({ module, ... }: module);
}
