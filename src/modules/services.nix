{
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, node, ... }: let
      services = config.infra.services;
      names = lib.attrNames services;
      cname = name: svc: if svc.containerName != "" then svc.containerName else name;
      entries = lib.mapAttrsToList (name: svc: "${name}:${cname name svc}") services;
    in {
      options.infra.services = lib.mkOption {
        type = with lib.types; attrsOf (submodule {
          options = {
            containerName = lib.mkOption {
              type = str;
              default = "";
              description = "container (and veth) name, defaults to the attribute name";
            };
            bindMounts = lib.mkOption {
              type = with lib.types; attrsOf raw;
              default = { };
              description = "extra paths to bind mount into the container";
            };
            config = lib.mkOption {
              type = raw;
              description = "nixos module running inside the container";
            };
          };
        });
        default = { };
        description = "containerised services";
      };

      config = {
        assertions = lib.mapAttrsToList (name: svc: {
          assertion = builtins.stringLength (cname name svc) <= 11;
          message = "infra.services.${name}: container name must be at most 11 characters";
        }) services;

        containers = lib.mapAttrs' (name: svc: let
          c = cname name svc;
        in lib.nameValuePair c {
          autoStart = true;
          privateNetwork = true;
          extraVeths."svc-${c}" = {
            hostAddress6 = "fe80::1/64";
            localAddress6 = "fe80::2/64";
          };
          allowedDevices = [ { node = "/dev/net/tun"; modifier = "rw"; } ];
          bindMounts = { "/run/svc-net" = { }; } // svc.bindMounts;
          config = { lib, pkgs, ... }: {
            imports = [ svc.config ];
            system.stateVersion = lib.mkDefault "25.11";
            networking.useNetworkd = true;
            networking.resolvconf.enable = false;
            services.resolved.enable = false;
            environment.etc."resolv.conf".text = ''
              nameserver 192.0.2.53
              search kn
            '';
            systemd.network.networks."40-svc-${c}" = {
              matchConfig.Name = "svc-${c}";
              networkConfig.KeepConfiguration = "static";
              linkConfig.MTUBytes = 1280;
              routes = [
                {
                  Destination = "${node.ula-prefix}/64";
                  Gateway = "fe80::1";
                  GatewayOnLink = true;
                }
              ];
            };
            systemd.services.svc-addr = {
              wantedBy = [ "multi-user.target" ];
              after = [ "systemd-networkd.service" ];
              wants = [ "systemd-networkd.service" ];
              path = [ pkgs.coreutils pkgs.iproute2 ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                ip -6 route del default via fe80::1 dev svc-${c} || true
                ip -6 addr replace "$(cat /run/svc-net/${name})"/128 dev svc-${c}
              '';
            };
          };
        }) services;

        systemd.services = lib.mapAttrs' (name: svc: let
          c = cname name svc;
        in lib.nameValuePair "container@${c}" {
          path = [ pkgs.coreutils pkgs.iproute2 pkgs.jq pkgs.passt config.systemd.package ];
          postStart = ''
            set -euo pipefail
            ip link set dev svc-${c} mtu 1280
            systemctl try-reload-or-restart bird || echo "bird reload failed" >&2
            cg=/sys/fs/cgroup$(systemctl show -p ControlGroup --value container@${c}.service)
            pid=$(head -n1 "$cg/payload/init.scope/cgroup.procs")
            ip netns delete kn-${c} 2>/dev/null || true
            ip netns attach kn-${c} "$pid"
            uplink=$(ip -4 -j route show default | jq -r '.[0].dev // empty')
            pasta --netns kn-${c} --runas 0 --no-netns-quit --config-net -I pasta0 \
              ''${uplink:+-i "$uplink"} \
              --dns-forward 192.0.2.53 --dns-host 127.0.0.53 \
              -t none -u none -T none -U none -f &
            sleep 1
            ip netns delete kn-${c} 2>/dev/null || true
            kill -0 $! 2>/dev/null || { echo "pasta failed to start" >&2; exit 1; }
          '';
        }) services;

        system.activationScripts.svc-net = {
          deps = [ "specialfs" ];
          supportsDryActivation = true;
          text = ''
            spec="${toString entries}"
            if [ "''${NIXOS_ACTION:-}" = dry-activate ]; then
              for s in $spec; do
                name=''${s%%:*}
                if [ -s "/run/svc-net/$name" ]; then
                  echo "svc-net: $name keeps $(cat "/run/svc-net/$name")"
                else
                  echo "svc-net: $name would get a new address"
                fi
              done
            else
              install -d -m 0755 /run/svc-net /run/namae.d /run/bird-services.d

              all=" ${toString names} "
              for f in /run/svc-net/*; do
                case "$all" in *" ''${f##*/} "*) ;; *) rm -f "$f" ;; esac
              done
              rm -f /run/namae.d/*.toml /run/bird-services.d/*.conf

              for s in $spec; do
                name=''${s%%:*}
                addr=/run/svc-net/$name
                if [ ! -s "$addr" ]; then
                  hex=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
                  echo "${node.ula-prefix}''${hex:0:4}:''${hex:4:4}:''${hex:8:4}:''${hex:12:4}" > "$addr"
                fi
                a=$(cat "$addr")
                printf '[[records]]\nname = "%s"\ntype = "AAAA"\nvalue = "%s"\n' \
                  "$name" "$a" > "/run/namae.d/$name.toml"
                printf 'protocol static svc_%s {\n  ipv6 { table igp_v6; };\n  route %s/128 via fe80::2 dev "svc-%s";\n}\n' \
                  "$name" "$a" "''${s#*:}" > "/run/bird-services.d/$name.conf"
              done

              ${config.systemd.package}/bin/systemctl try-reload-or-restart bird namae || true
            fi
          '';
        };
      };
    };
  } ];
}
