{ inputs, modules, ... }: {
  infra.nixos.test2 = {
    id = 2;
    hostname = "test2.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test2" ]);
    cryonet-bootstrap = true;
    k3s.server = true;
  };

  infra.modules = [ {
    tags = [ "nixos:test2" ];
    module = {
      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.hello = {};
      };
    };
  } ];
}
