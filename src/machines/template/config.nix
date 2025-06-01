{ inputs, modules, ... }: {
  infra.nixos.template = {
    hostname = "120.79.219.111";
    modules = (modules [ "nixos" ]) ++ (modules [ "nixos:template" ]);
    cryonet-bootstrap = true;
  };

  infra.modules = [ {
    tags = [ "nixos:template" ];
    module = {
      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets.hello = {};
      };
    };
  } ];
}
