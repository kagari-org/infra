{
  perSystem = { pkgs, lib, ... }: let
    charts = pkgs.callPackage ./_fetcher/_sources/generated.nix {}
      |> lib.filterAttrs (_: value: value ? src)
      # |> lib.mapAttrs (_: value: value.src);
      |> lib.mapAttrs (_: value: pkgs.runCommand "chart" {
        passthru = { inherit (value) path; };
      } ''
        mkdir $out
        tar xf ${value.src} -C $out
      '');
    joined = pkgs.runCommand "charts" {} ''
      mkdir $out
      ${lib.mapAttrsToList (name: value: ''
        ln -s ${value}/${value.path} $out/${name}
      '') charts |> lib.concatStringsSep "\n"}
    '';
  in {
    infra.hooks = ''
      ln -sf ${joined} src/manifest/charts
    '';
  };
}
