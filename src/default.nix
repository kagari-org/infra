{ lib, ... }: let
  listFiles = path: let
    files = builtins.readDir path;
    regular = files
      |> lib.filterAttrs (_: value: value == "regular")
      |> lib.attrNames
      |> map (x: /${path}/${x});
    directory = files
      |> lib.filterAttrs (_: value: value == "directory")
      |> lib.attrNames
      |> map (x: listFiles /${path}/${x})
      |> lib.flatten;
  in regular ++ directory;
in {
  imports = (listFiles ./parts) ++ (listFiles ./modules) ++ (listFiles ./machines);
}