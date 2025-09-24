let
  costs = { writeShellApplication, zx, bash, iproute2, iputils, ... }: writeShellApplication {
    name = "costs";
    runtimeInputs = [ zx bash iproute2 iputils ];
    text = "exec zx ${./costs.mjs} \"$@\"";
  };
in {
  perSystem = { pkgs, ... }: {
    packages.costs = pkgs.callPackage costs {};
  };
}
