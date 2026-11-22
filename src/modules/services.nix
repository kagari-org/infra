{
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, node, ... }: {
      options.infra.services = lib.mkOption {
        type = with lib.types; attrsOf (submodule {
          options = {
            container = lib.mkOption {
              type = str;
              default = "";
              description = "container (and veth) name, defaults to the attribute name";
            };
            flags = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              description = "extra systemd-nspawn flags";
            };
            devices = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              description = "extra device nodes to allow in the container";
            };
            nixpkgs = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "nixpkgs path used to evaluate the container";
            };
            mounts = lib.mkOption {
              type = with lib.types; attrsOf raw;
              default = { };
              description = "extra paths to bind mount into the container";
            };
            config = lib.mkOption {
              type = raw;
              description = "nixos module running inside the container";
            };
            filter = lib.mkOption {
              type = bool;
              default = true;
              description = "drop forwarded traffic from this container to bogon prefixes; domain allow rules require this";
            };
            allow = lib.mkOption {
              type = listOf (submodule {
                options = {
                  address = lib.mkOption {
                    type = nullOr str;
                    default = null;
                    description = "static destination address";
                  };
                  domain = lib.mkOption {
                    type = nullOr str;
                    default = null;
                    description = "destination domain, resolved periodically on the host";
                  };
                  port = lib.mkOption {
                    type = nullOr port;
                    default = null;
                    description = "destination port; null allows every port";
                  };
                };
              });
              default = [ ];
              description = "destinations exempt from the forward filter, by static address or domain";
            };
          };
        });
        default = { };
        description = "containerised services";
      };

      config = {
        assertions = let
          services = config.infra.services;
        in lib.mapAttrsToList (name: svc: {
          assertion = builtins.stringLength (if svc.container != "" then svc.container else name) <= 11;
          message = "infra.services.${name}: container name must be at most 11 characters";
        }) services
          ++ lib.concatMap (name: lib.imap0 (idx: rule: [
            {
              assertion = (rule.address == null) != (rule.domain == null);
              message = "infra.services.${name}: allow[${toString idx}] must set exactly one of address or domain";
            }
            {
              assertion = rule.domain == null || services.${name}.filter;
              message = "infra.services.${name}: allow[${toString idx}] uses a domain but filter = false";
            }
          ]) services.${name}.allow |> lib.flatten) (lib.attrNames services);

        networking.nftables.tables.svc-forward = let
          filtered = lib.filterAttrs (_: svc: svc.filter) config.infra.services;
          cname = name: svc: if svc.container != "" then svc.container else name;
          set-name = c: idx: family: "svc_${lib.replaceStrings [ "-" "." ] [ "_" "_" ] c}_d${toString idx}_${family}";
          accept = target: port: if port == null then [ "${target} accept" ] else [
            "${target} tcp dport ${toString port} accept"
            "${target} udp dport ${toString port} accept"
          ];
          service-sets = name: let
            c = cname name filtered.${name};
          in lib.concatStrings (lib.imap0 (idx: rule: lib.optionalString (rule.domain != null) ''
            set ${set-name c idx "v4"} { type ipv4_addr; }
            set ${set-name c idx "v6"} { type ipv6_addr; }
          '') filtered.${name}.allow);
          service-rules = name: let
            c = cname name filtered.${name};
            line = idx: rule: if rule.domain != null then
              let
                v4 = set-name c idx "v4";
                v6 = set-name c idx "v6";
              in lib.concatMap (target: accept target rule.port)
                [ "ip daddr @${v4}" "ip6 daddr @${v6}" ]
            else accept "${if lib.hasInfix ":" rule.address then "ip6" else "ip"} daddr ${rule.address}" rule.port;
          in map (line: ''iifname "svc-${c}" ${line}'')
            (lib.concatLists (lib.imap0 line filtered.${name}.allow)
              ++ [ "ip daddr @bogons_v4 drop" "ip6 daddr @bogons_v6 drop" ]);
        in lib.mkIf (filtered != { }) {
          family = "inet";
          content = ''
            set bogons_v4 {
              type ipv4_addr
              flags interval
              elements = {
                0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8,
                169.254.0.0/16, 172.16.0.0/12, 192.0.2.0/24, 192.88.99.0/24,
                192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24,
                224.0.0.0/4, 240.0.0.0/4
              }
            }

            set bogons_v6 {
              type ipv6_addr
              flags interval
              elements = {
                ::/8, 0100::/64, 2001:2::/48, 2001:10::/28, 2001:db8::/32,
                2002::/16, 3ffe::/16, fc00::/7, fe80::/10, fec0::/10, ff00::/8
              }
            }

            ${lib.concatMapStrings service-sets (lib.attrNames filtered)}

            chain forward {
              type filter hook forward priority -50; policy accept;

              iifname "svc-*" ct state established,related accept

              ${lib.concatStringsSep "\n  " (lib.concatMap service-rules (lib.attrNames filtered))}
            }
          '';
        };

        systemd.network.networks."40-svc-veth" = lib.mkIf (config.infra.services != { }) {
          matchConfig = { Kind = "veth"; Name = "svc-*"; };
          linkConfig.RequiredForOnline = false;
          address = [ "fe80::1/64" ];
          networkConfig = {
            DHCP = "no";
            LinkLocalAddressing = "no";
            IPv6AcceptRA = false;
          };
        };

        containers = lib.mapAttrs' (name: svc: let
          c = if svc.container != "" then svc.container else name;
        in lib.nameValuePair c {
          autoStart = true;
          privateNetwork = true;
          extraVeths."svc-${c}" = { };
          extraFlags = svc.flags;
          nixpkgs = if svc.nixpkgs != null then svc.nixpkgs else pkgs.path;
          allowedDevices = [ { node = "/dev/net/tun"; modifier = "rw"; } ]
            ++ map (node: { inherit node; modifier = "rwm"; }) svc.devices;
          bindMounts = { "/run/svc-net" = { }; } // svc.mounts;
          config = { lib, pkgs, ... }: {
            imports = [ svc.config ];
            system.stateVersion = lib.mkDefault "25.11";
            networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;
            networking.useNetworkd = true;
            networking.resolvconf.enable = false;
            services.resolved.enable = false;
            systemd.globalEnvironment.NIX_REMOTE = "daemon";
            environment.sessionVariables.NIX_REMOTE = "daemon";
            environment.variables.NIX_REMOTE = "daemon";
            environment.etc."resolv.conf".text = ''
              nameserver 192.0.2.53
              search kn
            '';
            systemd.network.networks."40-svc-${c}" = {
              matchConfig.Name = "svc-${c}";
              address = [ "fe80::2/64" ];
              networkConfig = {
                KeepConfiguration = "static";
                IPv6AcceptRA = false;
              };
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
                ip -6 addr replace "$(cat /run/svc-net/${name})"/128 dev svc-${c}
              '';
            };
          };
        }) config.infra.services;

        systemd.services = let
          services = config.infra.services;
          cname = name: svc: if svc.container != "" then svc.container else name;
          set-name = c: idx: family: "svc_${lib.replaceStrings [ "-" "." ] [ "_" "_" ] c}_d${toString idx}_${family}";
          filter-domains = pkgs.writeShellApplication {
            name = "svc-filter-domains";
            runtimeInputs = with pkgs; [ nftables getent gawk coreutils ];
            text = ''
              v4="$1" v6="$2" domain="$3"
              nft flush set inet svc-forward "$v4"
              nft flush set inet svc-forward "$v6"
              getent ahosts "$domain" | awk '{ print $1 }' | sort -u | while read -r ip; do
                case "$ip" in
                  *:*) nft add element inet svc-forward "$v6" "{" "$ip" "}" ;;
                  *)   nft add element inet svc-forward "$v4" "{" "$ip" "}" ;;
                esac
              done || true
            '';
          };
        in lib.mkMerge [
          (lib.mapAttrs' (name: svc: let
            c = cname name svc;
          in lib.nameValuePair "container@${c}" {
            path = [ pkgs.coreutils pkgs.iproute2 pkgs.jq pkgs.passt config.systemd.package config.services.bird.package ];
            postStart = ''
              set -euo pipefail
              ip link set dev svc-${c} mtu 1280
              for _ in $(seq 1 50); do
                case "$(birdc show interfaces 2>/dev/null || true)" in
                  *"svc-${c} "*) break ;;
                esac
                sleep 0.1
              done
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
          }) services)
          (lib.mapAttrs' (name: svc: let
            c = cname name svc;
          in lib.nameValuePair "svc-filter-${c}" {
            description = "Resolve domain filter entries for ${c}";
            after = [ "nftables.service" "namae.service" "network-online.target" ];
            wants = [ "network-online.target" ];
            startAt = "*-*-* *:0/1:00";
            script = "set -euo pipefail\n${lib.concatStrings (lib.imap0 (idx: rule: lib.optionalString (rule.domain != null) ''
              ${lib.getExe filter-domains} \
                ${lib.escapeShellArg (set-name c idx "v4")} \
                ${lib.escapeShellArg (set-name c idx "v6")} \
                ${lib.escapeShellArg rule.domain}
            '') svc.allow)}";
            serviceConfig = {
              Type = "oneshot";
              TimeoutStartSec = "60s";
            };
          }) (lib.filterAttrs (_: svc: svc.filter && lib.any (rule: rule.domain != null) svc.allow) services))
        ];

        system.activationScripts.svc-net = {
          deps = [ "specialfs" ];
          supportsDryActivation = true;
          text = ''
            spec="${toString (lib.mapAttrsToList (name: svc: "${name}:${if svc.container != "" then svc.container else name}") config.infra.services)}"
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

              all=" ${toString (lib.attrNames config.infra.services)} "
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
                  "''${name//-/_}" "$a" "''${s#*:}" > "/run/bird-services.d/$name.conf"
              done

              ${config.systemd.package}/bin/systemctl try-reload-or-restart bird namae || true
            fi
          '';
        };
      };
    };
  } ];
}
