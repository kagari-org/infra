{
  infra.modules = [ {
    type = "nixos";
    module = { config, pkgs, lib, ... }: let
      version = "0.6.5";

      multica-server = pkgs.buildGo126Module rec {
        pname = "multica-server";
        inherit version;

        src = pkgs.fetchFromGitHub {
          owner = "multica-ai";
          repo = "multica";
          rev = "v${version}";
          hash = "sha256-qM5uSgiL7I2omE7o7+iafoMiwCtu7MNxYTmiCD8RReU=";
        };

        modRoot = "server";
        vendorHash = "sha256-KJIrY4kLAQ5CBu/ClcXjLHG0FWvSX1ne06OG+ZkL75E=";

        subPackages = [
          "cmd/server"
          "cmd/migrate"
          "cmd/backfill_task_usage_hourly"
          "cmd/backfill_codex_usage_cache"
        ];

        ldflags = [ "-s" "-w" "-X main.version=${version}" ];

        postInstall = ''
          mv "$out/bin/server" "$out/bin/multica-server"
          mv "$out/bin/migrate" "$out/bin/multica-migrate"
          mv "$out/bin/backfill_task_usage_hourly" "$out/bin/multica-backfill-task-usage-hourly"
          mv "$out/bin/backfill_codex_usage_cache" "$out/bin/multica-backfill-codex-usage-cache"
          install -d "$out/share/multica"
          cp -R migrations "$out/share/multica/migrations"
        '';
      };

      multica-cli = pkgs.buildGo126Module {
        pname = "multica-cli";
        inherit version;

        src = multica-server.src;

        modRoot = "server";
        vendorHash = "sha256-KJIrY4kLAQ5CBu/ClcXjLHG0FWvSX1ne06OG+ZkL75E=";

        subPackages = [ "cmd/multica" ];

        env.CGO_ENABLED = 0;

        ldflags = [
          "-s"
          "-w"
          "-X main.version=${version}"
          "-X main.commit=nixpkg"
          "-X main.date=1970-01-01T00:00:00Z"
        ];
      };

      multica-web = pkgs.callPackage (
        {
          stdenv,
          fetchFromGitHub,
          fetchPnpmDeps,
          makeWrapper,
          nodejs_24,
          pnpm_10,
          pnpmConfigHook,
          remoteApiUrl ? "http://127.0.0.1:8080",
          nextPublicWsUrl ? "",
          appVersion ? version,
        }:
        stdenv.mkDerivation (finalAttrs: {
          pname = "multica-web";
          inherit version;

          src = pkgs.fetchFromGitHub {
            owner = "multica-ai";
            repo = "multica";
            rev = "v${finalAttrs.version}";
            hash = "sha256-qM5uSgiL7I2omE7o7+iafoMiwCtu7MNxYTmiCD8RReU=";
          };

          pnpmDeps = fetchPnpmDeps {
            inherit (finalAttrs) pname version src;
            pnpm = pnpm_10;
            fetcherVersion = 3;
            pnpmWorkspaces = [ "@multica/web..." ];
            hash = "sha256-S++seOVNAlXeOzrbYhxUCr8kCas67WWNWZ6U6BDhbtk=";
          };

          nativeBuildInputs = [ makeWrapper nodejs_24 pnpm_10 pnpmConfigHook ];

          # next/font/google fetches fonts during build; strip them for offline builds.
          postPatch = ''
            node <<'JS'
            const fs = require("fs");
            function replace(path, from, to) {
              let text = fs.readFileSync(path, "utf8");
              if (!text.includes(from)) throw new Error(`missing pattern in ''${path}: ''${from}`);
              fs.writeFileSync(path, text.replace(from, to));
            }
            replace("apps/web/app/layout.tsx", 'import { Inter, Geist_Mono, Source_Serif_4 } from "next/font/google";', "");
            replace("apps/web/app/layout.tsx", `const inter = Inter({
              subsets: ["latin"],
              style: ["normal", "italic"],
              variable: "--font-inter",
            });`, 'const inter = { variable: "" };');
            replace("apps/web/app/layout.tsx", `const geistMono = Geist_Mono({
              subsets: ["latin"],
              variable: "--font-mono",
              fallback: ["ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace"],
            });`, 'const geistMono = { variable: "" };');
            replace("apps/web/app/layout.tsx", `const sourceSerif = Source_Serif_4({
              subsets: ["latin"],
              style: ["normal", "italic"],
              variable: "--font-serif",
              fallback: [
                "ui-serif",
                "Iowan Old Style",
                "Apple Garamond",
                "Baskerville",
                "Times New Roman",
                "serif",
              ],
            });`, 'const sourceSerif = { variable: "" };');
            replace("apps/web/app/(landing)/layout.tsx", 'import { Instrument_Serif } from "next/font/google";', "");
            replace("apps/web/app/(landing)/layout.tsx", `const instrumentSerif = Instrument_Serif({
              subsets: ["latin"],
              weight: "400",
              variable: "--font-instrument-serif",
            });`, 'const instrumentSerif = { variable: "" };');
            JS
          '';

          pnpmInstallFlags = [ "--filter=@multica/web..." ];

          env = {
            REMOTE_API_URL = remoteApiUrl;
            NEXT_PUBLIC_WS_URL = nextPublicWsUrl;
            NEXT_PUBLIC_APP_VERSION = appVersion;
            STANDALONE = "true";
            NODE_ENV = "production";
            NEXT_TELEMETRY_DISABLED = "1";
          };

          buildPhase = ''
            runHook preBuild
            pnpm --filter @multica/web build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -d "$out/share/multica-web"
            cp -R apps/web/.next/standalone/* "$out/share/multica-web/"
            install -d "$out/share/multica-web/apps/web/.next"
            cp -R apps/web/.next/static "$out/share/multica-web/apps/web/.next/static"
            cp -R apps/web/public "$out/share/multica-web/apps/web/public"
            makeWrapper ${lib.getExe nodejs_24} "$out/bin/multica-web" \
              --chdir "$out/share/multica-web" \
              --set-default NODE_ENV production \
              --set-default HOSTNAME 127.0.0.1 \
              --set-default PORT 3000 \
              --add-flags "$out/share/multica-web/apps/web/server.js"
            runHook postInstall
          '';
        })
      ) {};

      cfg = config.services.multica;

      webPackage =
        if cfg.package.web ? override
        then cfg.package.web.override {
          remoteApiUrl = cfg.web.remoteApiUrl;
          nextPublicWsUrl = cfg.web.nextPublicWsUrl;
          appVersion = version;
        }
        else cfg.package.web;

      localDatabaseUrl = "postgres://${cfg.database.user}@/${cfg.database.name}?host=/run/postgresql&sslmode=disable";
      databaseUrl =
        if cfg.database.createLocally
        then localDatabaseUrl
        else cfg.database.url;

      dbSetup = pkgs.writeShellScript "multica-db-setup" ''
        set -euo pipefail

        ${config.services.postgresql.package}/bin/psql -d postgres -v ON_ERROR_STOP=1 -c 'ALTER DATABASE "${cfg.database.name}" OWNER TO "${cfg.database.user}";'

        ${config.services.postgresql.package}/bin/psql -d "${cfg.database.name}" -v ON_ERROR_STOP=1 <<'SQL'
        CREATE EXTENSION IF NOT EXISTS vector;
        ALTER SCHEMA public OWNER TO "${cfg.database.user}";
        GRANT USAGE, CREATE ON SCHEMA public TO "${cfg.database.user}";
        GRANT ALL PRIVILEGES ON DATABASE "${cfg.database.name}" TO "${cfg.database.user}";
        SQL
      '';
    in {
      options.services.multica = {
        enable = lib.mkEnableOption "Multica";

        stateDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/multica";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };

        package = {
          server = lib.mkOption {
            type = lib.types.package;
            default = multica-server;
          };
          web = lib.mkOption {
            type = lib.types.package;
            default = multica-web;
          };
          cli = lib.mkOption {
            type = lib.types.package;
            default = multica-cli;
          };
        };

        database = {
          createLocally = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          name = lib.mkOption {
            type = lib.types.str;
            default = "multica";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "multica";
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        backend = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          publicUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          trustedProxies = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          metricsAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        frontend = {
          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 3000;
          };
          publicUrl = lib.mkOption {
            type = lib.types.str;
            default = "http://localhost:3000";
          };
        };

        web = {
          remoteApiUrl = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:${toString cfg.backend.port}";
          };
          nextPublicWsUrl = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };

        storage = {
          localUploadDir = lib.mkOption {
            type = lib.types.str;
            default = "${cfg.stateDir}/uploads";
          };
          localUploadBaseUrl = lib.mkOption {
            type = lib.types.str;
            default = cfg.frontend.publicUrl;
          };
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.database.createLocally || cfg.database.url != null;
            message = "services.multica.database.url is required when database.createLocally = false.";
          }
          {
            assertion = !lib.hasSuffix "/" cfg.frontend.publicUrl;
            message = "services.multica.frontend.publicUrl must not have a trailing slash.";
          }
          {
            assertion = cfg.backend.publicUrl == null || !lib.hasSuffix "/" cfg.backend.publicUrl;
            message = "services.multica.backend.publicUrl must not have a trailing slash.";
          }
        ];

        services.postgresql = lib.mkIf cfg.database.createLocally {
          ensureDatabases = [ cfg.database.name ];
          ensureUsers = [{
            name = cfg.database.user;
            ensureDBOwnership = true;
          }];
        };

        systemd.services.multica-db-setup = lib.mkIf cfg.database.createLocally {
          after = [ "postgresql.service" "postgresql-setup.service" ];
          requires = [ "postgresql.service" "postgresql-setup.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "postgres";
            ExecStart = dbSetup;
          };
        };

        systemd.services.multica-migrate = {
          after = lib.optional cfg.database.createLocally "multica-db-setup.service";
          requires = lib.optional cfg.database.createLocally "multica-db-setup.service";
          before = [ "multica-backend.service" ];
          wantedBy = [ "multi-user.target" ];
          environment = lib.optionalAttrs (databaseUrl != null) {
            DATABASE_URL = databaseUrl;
          };
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
            User = "multica";
            Group = "multica";
            StateDirectory = "multica";
            WorkingDirectory = "${cfg.package.server}/share/multica";
            ExecStart = "${cfg.package.server}/bin/multica-migrate up";
            EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          };
        };

        systemd.services.multica-backend = {
          after = [ "network.target" "multica-migrate.service" ];
          requires = [ "multica-migrate.service" ];
          wantedBy = [ "multi-user.target" ];
          environment = lib.optionalAttrs (databaseUrl != null) {
            DATABASE_URL = databaseUrl;
          } // {
            PORT = toString cfg.backend.port;
            APP_ENV = "production";
            FRONTEND_ORIGIN = cfg.frontend.publicUrl;
            CORS_ALLOWED_ORIGINS = cfg.frontend.publicUrl;
            GOOGLE_REDIRECT_URI = "${cfg.frontend.publicUrl}/auth/callback";
            MULTICA_APP_URL = cfg.frontend.publicUrl;
            LOCAL_UPLOAD_DIR = cfg.storage.localUploadDir;
            LOCAL_UPLOAD_BASE_URL = cfg.storage.localUploadBaseUrl;
          } // lib.optionalAttrs (cfg.backend.publicUrl != null) {
            MULTICA_PUBLIC_URL = cfg.backend.publicUrl;
          } // lib.optionalAttrs (cfg.backend.trustedProxies != [ ]) {
            MULTICA_TRUSTED_PROXIES = lib.concatStringsSep "," cfg.backend.trustedProxies;
          } // lib.optionalAttrs (cfg.backend.metricsAddress != null) {
            METRICS_ADDR = cfg.backend.metricsAddress;
          };
          serviceConfig = {
            DynamicUser = true;
            User = "multica";
            Group = "multica";
            StateDirectory = "multica";
            WorkingDirectory = "${cfg.package.server}/share/multica";
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.storage.localUploadDir}";
            ExecStart = "${cfg.package.server}/bin/multica-server";
            Restart = "on-failure";
            EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          };
        };

        systemd.services.multica-web = {
          after = [ "network.target" "multica-backend.service" ];
          wants = [ "multica-backend.service" ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            NODE_ENV = "production";
            HOSTNAME = cfg.frontend.listenAddress;
            PORT = toString cfg.frontend.port;
          };
          serviceConfig = {
            DynamicUser = true;
            User = "multica";
            Group = "multica";
            ExecStart = "${webPackage}/bin/multica-web";
            Restart = "on-failure";
          };
        };
      };
    };
  } ];
}
