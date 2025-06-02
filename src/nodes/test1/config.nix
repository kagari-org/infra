{ inputs, modules, ... }: {
  infra.nodes.test1 = {
    id = 1;
    address = "test1.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test1" ]);
    cryonet.bootstrap = true;
    k3s = {
      server = true;
      endpoint = true;
    };
  };

  infra.modules = [ {
    tags = [ "nixos:test1" ];
    module = {};
  } ];
}
