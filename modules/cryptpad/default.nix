flake: { config, lib, pkgs, ... }:

let
  inherit (lib) types strings mdDoc mkOption mkIf mkMerge;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) cryptpad;

  cfg = config.services.cryptpad;

  # The Cryptpad configuration file is not JSON, but a JavaScript source file that assigns a JSON configuration
  # object to a variable and exports it.
  configFile = builtins.toFile "cryptpad_config.js" ''
    module.exports = ${builtins.toJSON cfg.config}
  '';

  # Derive domain names for Nginx configuration from Cryptpad configuration
  mainDomain = strings.removePrefix "https://" cfg.config.httpUnsafeOrigin;
  sandboxDomain =
    if cfg.config.httpSafeOrigin == null then mainDomain else strings.removePrefix "https://" cfg.config.httpSafeOrigin;

in
{
  # Some workaround due to `cryptpad` being a disabled module name:
  # Disabling the rename.nix module is necessary to be able to use the name 'cryptpad'
  disabledModules = [ "rename.nix" ];
  # The following import is necessary when disabling the rename.nix module above
  imports = [
    (lib.mkAliasOptionModuleMD [ "environment" "checkConfigurationOptions" ] [ "_module" "check" ])
  ];


  options = {
    services.cryptpad = {
      enable = lib.mkEnableOption "cryptpad";

      package = mkOption {
        type = types.package;
        default = cryptpad;
        description = mdDoc ''
          The Cryptpad package to use with the service.
        '';
      };

      configureNginx = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Configure Nginx as a reverse proxy for Cryptpad.
          Note that this makes some assumptions on your setup, and configures settings that will
          affect other virtualHosts running on your Nginx instance, if any.
          Alternatively you can configure a reverse-proxy of your choice.
        '';
      };

      clientMaxBodySize = mkOption {
        default = "150m";
        type = types.str;
        description = mdDoc ''
          Value for the Nginx client_max_body_size header. Only relevant if `configureNginx` is `true`.
        '';
      };

      hstsMaxAge = mkOption {
        type = types.ints.positive;
        default = 63072000;
        description = mdDoc ''
          Value for the `max-age` directive of the HTTP `Strict-Transport-Security` header.
          Only relevant if `configureNginx` is `true`.
          See section 6.1.1 of IETF RFC 6797 for detailed information on this
          directive and header.
        '';
      };

      config = mkOption {
        type = types.submodule {
          freeformType = (pkgs.formats.json { }).type;
          options = {
            httpUnsafeOrigin = mkOption {
              type = types.str;
              example = "https://cryptpad.example.com";
              default = "";
              description = mdDoc "This is the URL that users will enter to load your instance.";
            };
            httpSafeOrigin = mkOption {
              type = types.nullOr types.str;
              example = "https://cryptpad-ui.example.com";
              description = mdDoc ''
                This is the URL that is used for the 'sandbox' described in the Cryptpad documentation.
              '';
            };
            httpAddress = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = mdDoc "Address on which the Node.js server should listen.";
            };
            httpPort = mkOption {
              type = types.int;
              default = 3000;
              description = mdDoc "Port on which the Node.js server should listen.";
            };
            maxWorkers = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = mdDoc "Number of child processes, defaults to number of cores available.";
            };
            adminKeys = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = mdDoc "List of public signing keys of users that can access the admin panel.";
              example = [ "[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]" ];
            };
            filePath = mkOption {
              type = types.str;
              default = "./datastore/";
              description = mdDoc ''
                Specifies the directory where files are stored.
              '';
            };
            archivePath = mkOption {
              type = types.str;
              default = "./data/archive";
              description = mdDoc ''
                Specifies the directory where archived data is stored.
              '';
            };
            pinPath = mkOption {
              type = types.str;
              default = "./data/pins";
              description = mdDoc ''
                Specifies the directory where pinned documents are stored.
              '';
            };
            taskPath = mkOption {
              type = types.str;
              default = "./data/tasks";
              description = mdDoc ''
                Specifies the directory where scheduled tasks are stored.
              '';
            };
            blockPath = mkOption {
              type = types.str;
              default = "./block";
              description = mdDoc ''
                Specifies the directory where users' authenticated blocks are stored.
              '';
            };
            blobPath = mkOption {
              type = types.str;
              default = "./blob";
              description = mdDoc ''
                Specifies the directory where encrypted blobs are stored.
              '';
            };
            blobStagingPath = mkOption {
              type = types.str;
              default = "./data/blobstage";
              description = mdDoc ''
                Specifies the directory where incomplete blobs are stored.
              '';
            };
            decreePath = mkOption {
              type = types.str;
              default = "./data/decrees";
              description = mdDoc ''
                Specifies the directory where decrees are stored.
              '';
            };
            logPath = mkOption {
              type = types.oneOf [ types.str types.bool];
              default = false;
              description = mdDoc ''
                Specifies the directory where logs are stored. Set to false (or nothing) if you'd rather
                not log.
              '';
            };
            logToStdout = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc "Controls whether log output should go to stdout of the systemd service";
            };
            logLevel = mkOption {
              type = types.str;
              default = "info";
              description = mdDoc "Controls log level";
            };
            logFeedback = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc ''
                Provide usage feedback to the Cryptpad admin.
              '';
            };
            verbose = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc "Controls verbose logging.";
            };
            installMethod = mkOption {
              type = types.str;
              default = "nixos";
              description = mdDoc ''
                Install method information included in server telemetry to voluntarily indicate how many
                instances are using unofficial installation methods such as Nix.
              '';
            };
            blockDailyCheck = mkOption {
              type = types.bool;
              default = true;
              description = mdDoc ''
                Disable telemetry. This setting is only effective if the 'Disable server telemetry' setting in the
                admin menu has been untouched, and will be ignored once set there either way.
              '';
            };
          };
        };
        description = mdDoc ''
          Cryptpad configuration settings.
          See https://github.com/cryptpad/cryptpad/blob/main/config/config.example.js for a more extensive
          reference documentation.
          Test your deployed instance through `https://<domain>/checkup/`.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users = {
        users.cryptpad = {
          isSystemUser = true;
          group = "cryptpad";
        };
        groups.cryptpad = { };
      };

      systemd.services.cryptpad = {
        description = "Cryptpad service";
        wantedBy = [ "multi-user.target" ];
        after = [ "networking.target" ];
        environment = {
          CRYPTPAD_CONFIG = configFile;
          HOME = "%S/cryptpad";
        };
        serviceConfig = {
          User = "cryptpad";
          ExecStart = "${cfg.package}/bin/cryptpad";
          PrivateTmp = true;
          Restart = "always";
          StateDirectory = "cryptpad";
          WorkingDirectory = "%S/cryptpad";
        };
      };
    }

    (mkIf cfg.configureNginx {
      assertions = [
        {
          assertion = cfg.config.httpUnsafeOrigin != "";
          message = "services.cryptpad.config.httpUnsafeOrigin is required";
        }
        {
          assertion = strings.hasPrefix "https://" cfg.config.httpUnsafeOrigin;
          message = "services.cryptpad.config.httpUnsafeOrigin must start with https://";
        }
        {
          assertion = cfg.config.httpSafeOrigin == null || strings.hasPrefix "https://" cfg.config.httpSafeOrigin;
          message = "services.cryptpad.config.httpSafeOrigin must start with https:// (or be unset)";
        }
      ];

      services.nginx = {
        enable = true;
        recommendedTlsSettings = true;
        virtualHosts = mkMerge [
          {
            "${mainDomain}" = {
              serverAliases = lib.optionals (cfg.config.httpSafeOrigin != null) [ sandboxDomain ];
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${cfg.config.httpAddress}:${builtins.toString cfg.config.httpPort}";
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
}
