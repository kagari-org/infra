{ infra.modules = [{
  type = "home";
  module = {
    infra.services.trilium.config = { pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [ 8080 ];
      services.trilium-server = {
        enable = true;
        host = "::";
        # TODO: drop once patchelf stops corrupting the bundled node (the
        # non-PIE ELF gets mis-mapped and segfaults in ld.so); nixpkgs' node is
        # the same version trilium ships.
        package = pkgs.trilium-server.overrideAttrs (o: {
          postInstall = (o.postInstall or "") + ''
            rm -rf $out/share/trilium-server/node
            mkdir -p $out/share/trilium-server/node/bin
            ln -s ${pkgs.nodejs_24}/bin/node $out/share/trilium-server/node/bin/node
          '';
        });
      };
    };
  };
}]; }
