{ inputs, modules, ... }: {
  infra.nodes.test3 = {
    id = 3;
    address = "test3.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test3" ]);
    cryonet.bootstrap = true;
  };

  infra.modules = [ {
    tags = [ "nixos:test3" ];
    module = {};
  } ];
}
