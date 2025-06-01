{ inputs, modules, ... }: {
  infra.nixos.test3 = {
    id = 3;
    hostname = "test3.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test3" ]);
    cryonet-bootstrap = true;
  };

  infra.modules = [ {
    tags = [ "nixos:test3" ];
    module = {
      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.hello = {};
      };
    };
  } ];
}
