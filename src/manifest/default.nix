{
  perSystem = { pkgs, lib, ... }: let
    charts = pkgs.callPackage ./_fetcher/_sources/generated.nix {}
      |> lib.filterAttrs (_: value: value ? src)
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
    packages.manifest = pkgs.stdenv.mkDerivation {
      name = "manifest.yaml";
      src = ./.;
      nativeBuildInputs = with pkgs; [ kustomize kubernetes-helm ];
      buildPhase = ''
        ln -s ${joined} charts
        kustomize build . --enable-helm --load-restrictor LoadRestrictionsNone > $out
      '';
    };
    infra.hooks = ''
      rm src/manifest/charts
      ln -s ${joined} src/manifest/charts
    '';
  };
}
