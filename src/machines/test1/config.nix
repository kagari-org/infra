{ inputs, modules, ... }: {
  infra.nixos.test1 = {
    hostname = "test1.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test1" ]);
    cryonet-bootstrap = true;
  };

  infra.modules = [ {
    tags = [ "nixos:test1" ];
    module = {
      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.hello = {};
      };
    };
  } ];
}
