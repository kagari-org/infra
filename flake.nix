{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.deploy.url = "github:serokell/deploy-rs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.cryonet.url = "github:kagari-org/cryonet";

  outputs = inputs@{
    self, nixpkgs, flake-parts, ...
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ ./src ];
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    transposition.lib = {};
    debug = true;
    perSystem = { pkgs, inputs', ... }: {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [
          sops age ssh-to-age
          inputs'.deploy.packages.default
          inputs'.sops-nix.packages.default
        ];
      };
    };
  };
}
