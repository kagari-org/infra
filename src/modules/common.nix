{ inputs, ... }: {
  infra.modules = [ {
    type = "nixos";
    module = { lib, name, ... }: {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      system.stateVersion = "25.05";
      services.openssh.enable = true;
      networking.hostName = lib.mkDefault name;
      nix = {
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
        registry.p.flake = inputs.nixpkgs;
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
      };
      users = {
        mutableUsers = false;
        users.root = {
          hashedPassword = "$y$j9T$oNQT1.g7HSe/2/kjy8fw90$JVJwmgHoK3IutMkX4UMiH0TMpJfhz9maILb8NlFwZE6";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqu43h92/UcQLf+E7AnUqmjjdGLkcazB9Z9nNRferqD tablet"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmgw6CGq5fPlVdJc5DhgXzlW2GSimAd1xiRbEZWS0KG phone"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSZb49HJ8gM5fufmFZoa7ZmHcVsAPzkPY4l8LbGvmfJ umi"
          ];
        };
      };
    };
  } ];
}
