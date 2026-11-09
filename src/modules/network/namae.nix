{ withSystem, ... }: {
  infra.modules = [ {
    type = "nixos";
    module = withSystem "x86_64-linux" ({ inputs', ... }: { config, pkgs, lib, node, ... }: {
      options.services.namae.records = lib.mkOption {
        type = with lib.types; listOf (submodule {
          options.name = lib.mkOption {
            type = str;
            description = "record name";
          };
          options.type = lib.mkOption {
            type = enum [ "A" "AAAA" "CNAME" "TXT" ];
            description = "record type";
          };
          options.value = lib.mkOption {
            type = nullOr str;
            default = null;
            description = "static value";
          };
          options.from-interface = lib.mkOption {
            type = nullOr str;
            default = null;
            description = "interface to publish addresses from (A and AAAA only)";
          };
          options.ttl = lib.mkOption {
            type = nullOr (ints.between 0 4294967295);
            default = null;
            description = "record ttl";
          };
          options.priority = lib.mkOption {
            type = ints.unsigned;
            default = 100;
            description = "conflict priority";
          };
          options.publish = lib.mkOption {
            type = bool;
            default = true;
            description = "gossip to peers";
          };
        });
        default = [];
        description = "records";
      };

      config = {
        sops.secrets.namae-secret = {
          sopsFile = ./secrets.yaml;
          reloadUnits = [ "namae.service" ];
        };

        environment.etc = lib.listToAttrs (lib.imap0 (i: record: {
          name = "namae.d/${toString i}-${lib.replaceStrings [ "*" "/" ] [ "_" "_" ] record.name}-${record.type}.toml";
          value.source = (pkgs.formats.toml {}).generate "namae-record.toml" {
            records = [ (
              { inherit (record) name type; }
              // lib.optionalAttrs (record.value != null) { value = record.value; }
              // lib.optionalAttrs (record.from-interface != null) { from_interface = record.from-interface; }
              // lib.optionalAttrs (record.ttl != null) { ttl = record.ttl; }
              // lib.optionalAttrs (record.priority != 100) { priority = record.priority; }
              // lib.optionalAttrs (!record.publish) { publish = record.publish; }
            ) ];
          };
        }) config.services.namae.records) // {
          "namae.toml".source = (pkgs.formats.toml {}).generate "namae.toml" {
            zone = "kn.";
            dns_listen = [ "0.0.0.0:15353" ];
            secret_file = config.sops.secrets.namae-secret.path;
            id = node.id;
          };
        };

        environment.systemPackages = [ inputs'.namae.packages.default ];

        services.resolved.dnsDelegates.namae.Delegate = {
          DNS = [ "127.0.0.1:15353" ];
          Domains = "kn.";
        };

        systemd.services.namae = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" "bird.service" "sops-install-secrets.service" ];
          wants = [ "sops-install-secrets.service" ];
          reloadTriggers = config.environment.etc
            |> lib.filterAttrs (name: _: lib.hasPrefix "namae" name)
            |> lib.attrValues
            |> lib.map (entry: entry.source);
          serviceConfig = {
            ExecReload = "${inputs'.namae.packages.default}/bin/namae ctl reload";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          script = ''
            exec ${inputs'.namae.packages.default}/bin/namae daemon \
              --config /etc/namae.toml \
              --config-dir /etc/namae.d
          '';
        };
      };
    });
  } ];
}
