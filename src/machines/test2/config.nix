{ inputs, modules, ... }: {
  infra.nixos.test2 = {
    hostname = "test2.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test2" ]);
    cryonet-bootstrap = true;
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
