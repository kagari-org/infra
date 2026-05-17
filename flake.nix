{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.deploy.url = "github:serokell/deploy-rs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.cryonet.url = "github:kagari-org/cryonet";

  outputs = inputs@{
    self, nixpkgs, flake-parts, import-tree, ...
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ (import-tree ./src) ];
    systems = [ "x86_64-linux" ];
    transposition.lib = {};
    debug = true;
    perSystem = { config, pkgs, inputs', ... }: {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          sops age ssh-to-age nvfetcher
          kustomize kubernetes-helm
          inputs'.deploy.packages.default
          inputs'.sops-nix.packages.default
        ];
      };
    };
  };
}
