{ inputs, modules, ... }: {
  infra.nodes.test2 = {
    id = 2;
    address = "test2.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test2" ]);
    cryonet.bootstrap = true;
    k3s.server = true;
  };

  infra.modules = [ {
    tags = [ "nixos:test2" ];
    module = {};
  } ];
}
