{ inputs, modules, ... }: {
  infra.nixos.test4 = {
    id = 4;
    hostname = "test4.ff.ci";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:test4" ]);
  };

  infra.modules = [ {
    tags = [ "nixos:test4" ];
    module = {
      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.hello = {};
      };
    };
  } ];
}
