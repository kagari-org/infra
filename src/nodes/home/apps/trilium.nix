{ infra.modules = [{
  type = "home";
  module = { pkgs, ... }: {
    services.trilium-server = {
      enable = true;
      host = "0.0.0.0";
      port = 3007;
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
}]; }
