{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types strings mkOption mkIf mkMerge;

  cfg = config.services.cryptpad;

  # The Cryptpad configuration file is not JSON, but a JavaScript source file that assigns a JSON configuration
  # object to a variable and exports it.
  cryptpadConfigFile = builtins.toFile "cryptpad_config.js" ''
    module.exports = ${builtins.toJSON cfg.settings}
  '';

  # Derive domain names for Nginx configuration from Cryptpad configuration
  mainDomain = strings.removePrefix "https://" cfg.settings.httpUnsafeOrigin;
  sandboxDomain =
    if cfg.settings.httpSafeOrigin == null
    then mainDomain
    else strings.removePrefix "https://" cfg.settings.httpSafeOrigin;
in {
  # FIXME: `cryptpad` is a disabled module name in nixpkgs.
  # It can be used by disabling the rename.nix module.
  # Hopefully this can be removed when https://github.com/NixOS/nixpkgs/pull/251687 gets merged.
  disabledModules = ["rename.nix"];
  # The following import is necessary when disabling the rename.nix module above
  imports = [
    (lib.mkAliasOptionModuleMD ["environment" "checkConfigurationOptions"] ["_module" "check"])
  ];

  options = {
    services.cryptpad = {
      enable = lib.mkEnableOption "cryptpad";

      configureNginx = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Configure Nginx as a reverse proxy for Cryptpad.
          Note that this makes some assumptions on your setup, and configures settings that will
          affect other virtualHosts running on your Nginx instance, if any.
          Alternatively you can configure a reverse-proxy of your choice.
        '';
      };

      settings = mkOption {
        description = ''
          Cryptpad configuration settings.
          See https://github.com/cryptpad/cryptpad/blob/main/config/config.example.js for a more extensive
          reference documentation.
          Test your deployed instance through `https://<domain>/checkup/`.
        '';
        type = types.submodule {
          freeformType = (pkgs.formats.json {}).type;
          options = {
            httpUnsafeOrigin = mkOption {
              type = types.str;
              example = "https://cryptpad.example.com";
              default = "";
              description = "This is the URL that users will enter to load your instance.";
            };
            httpSafeOrigin = mkOption {
              type = types.nullOr types.str;
              example = "https://cryptpad-ui.example.com";
              description = ''
                This is the URL that is used for the 'sandbox' described in the Cryptpad documentation.
              '';
            };
            httpAddress = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "Address on which the Node.js server should listen.";
            };
            httpPort = mkOption {
              type = types.int;
              default = 3000;
              description = "Port on which the Node.js server should listen.";
            };
            websocketPort = mkOption {
              type = types.int;
              default = 3003;
              description = "Port for the websocket that needs to be separate";
            };
            maxWorkers = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Number of child processes, defaults to number of cores available.";
            };
            adminKeys = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "List of public signing keys of users that can access the admin panel.";
              example = ["[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]"];
            };
            logToStdout = mkOption {
              type = types.bool;
              default = false;
              description = "Controls whether log output should go to stdout of the systemd service";
            };
            logLevel = mkOption {
              type = types.str;
              default = "info";
              description = "Controls log level";
            };
            blockDailyCheck = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Disable telemetry. This setting is only effective if the 'Disable server telemetry' setting in the
                admin menu has been untouched, and will be ignored once set there either way.
              '';
            };
            installMethod = mkOption {
              type = types.str;
              default = "nixos";
              description = ''
                Install method information included in server telemetry to voluntarily indicate how many
                instances are using unofficial installation methods such as Nix.
              '';
            };
          };
        };
      };

      clientMaxBodySize = mkOption {
        default = "150m";
        type = types.str;
        description = ''
          Value for the Nginx client_max_body_size header. Only relevant if `configureNginx` is `true`.
        '';
      };

      hstsMaxAge = mkOption {
        type = types.ints.positive;
        default = 63072000;
        description = ''
          Value for the `max-age` directive of the HTTP `Strict-Transport-Security` header.
          Only relevant if `configureNginx` is `true`.
          See section 6.1.1 of IETF RFC 6797 for detailed information on this
          directive and header.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      systemd.services.cryptpad = {
        description = "Cryptpad service";
        wantedBy = ["multi-user.target"];
        after = ["networking.target"];
        environment = {
          CRYPTPAD_CONFIG = cryptpadConfigFile;
          HOME = "%S/cryptpad";
          PWD = "%S/cryptpad";
        };

        # See https://github.com/cryptpad/cryptpad/blob/main/docs/cryptpad.service
        serviceConfig = {
          BindReadOnlyPaths = [
            cryptpadConfigFile
            # apparently needs proc for workers management
            "/proc"
            "/dev/urandom"
          ];
          DynamicUser = true;
          StateDirectory = "cryptpad";
          ExecStart = lib.getExe pkgs.cryptpad;
          WorkingDirectory = "%S/cryptpad";
          # security way too many numerous options, from the systemd-analyze security output
          # at end of test: block everything except
          # - SystemCallFiters=@resources is required for node
          # - MemoryDenyWriteExecute for node JIT
          # - RestrictAddressFamilies=~AF_(INET|INET6) / PrivateNetwork to bind to sockets
          # - IPAddressDeny likewise allow localhost if binding to localhost or any otherwise
          # - PrivateUsers somehow service doesn't start with that
          # - DeviceAllow (char-rtc r added by ProtectClock)
          AmbientCapabilities = "";
          CapabilityBoundingSet = "";
          DeviceAllow = "";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RuntimeDirectoryMode = "700";
          SocketBindAllow = [
            "tcp:${builtins.toString cfg.settings.httpPort}"
            "tcp:${builtins.toString cfg.settings.websocketPort}"
          ];
          SocketBindDeny = ["any"];
          StateDirectoryMode = "0700";
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@pkey"
            "@system-service"
            "~@chown"
            "~@keyring"
            "~@memlock"
            "~@privileged"
            "~@resources"
            "~@setuid"
            "~@timer"
          ];
          UMask = "0077";
        };
        confinement = {
          enable = true;
          binSh = null;
          mode = "chroot-only";
        };
      };
    }

    # block external network access if not phoning home and
    # binding to localhost (default)
    (
      mkIf
      (
        cfg.settings.blockDailyCheck
        && (builtins.elem cfg.settings.httpAddress [
          "127.0.0.1"
          "::1"
        ])
      )
      {
        systemd.services.cryptpad = {
          serviceConfig = {
            IPAddressAllow = ["localhost"];
            IPAddressDeny = ["any"];
          };
        };
      }
    )

    # .. conversely allow DNS & TLS if telemetry is explicitly enabled
    (mkIf (!cfg.settings.blockDailyCheck) {
      systemd.services.cryptpad = {
        serviceConfig = {
          BindReadOnlyPaths = [
            "-/etc/resolv.conf"
            "-/run/systemd"
            "/etc/hosts"
            "/etc/ssl/certs/ca-certificates.crt"
          ];
        };
      };
    })

    (mkIf cfg.configureNginx {
      assertions = [
        {
          assertion = cfg.settings.httpUnsafeOrigin != "";
          message = "services.cryptpad.settings.httpUnsafeOrigin is required";
        }
        {
          assertion = strings.hasPrefix "https://" cfg.settings.httpUnsafeOrigin;
          message = "services.cryptpad.settings.httpUnsafeOrigin must start with https://";
        }
        {
          assertion = cfg.settings.httpSafeOrigin == null || strings.hasPrefix "https://" cfg.settings.httpSafeOrigin;
          message = "services.cryptpad.settings.httpSafeOrigin must start with https:// (or be unset)";
        }
      ];

      services.nginx = {
        enable = true;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;

        virtualHosts = mkMerge [
          {
            "${mainDomain}" = {
              serverAliases = lib.optionals (cfg.settings.httpSafeOrigin != null) [sandboxDomain];
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${cfg.settings.httpAddress}:${builtins.toString cfg.settings.httpPort}";
                proxyWebsockets = true;
                extraConfig = ''
                  client_max_body_size ${cfg.clientMaxBodySize};
                  add_header Strict-Transport-Security "max-age=${toString cfg.hstsMaxAge}; includeSubDomains" always;
                '';
              };
            };
          }
        ];
      };
    })
  ]);

  meta.maintainers = with lib.maintainers; [michaelshmitty];
}
