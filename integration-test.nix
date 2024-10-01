{
  nixpkgs,
  cryptpadModule,
}: {pkgs, ...}: let
  certs = import "${nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
in {
  name = "cryptpad";
  meta.maintainers = with pkgs.lib.maintainers; [michaelshmitty];

  nodes.server = {
    config,
    pkgs,
    lib,
    ...
  }: {
    virtualisation.memorySize = 4096;

    imports = [cryptpadModule];

    services.cryptpad = {
      enable = true;
      configureNginx = false;
      settings = {
        httpUnsafeOrigin = "https://${serverDomain}";
        httpSafeOrigin = "https://${serverDomain}";
      };
    };

    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;

      virtualHosts."${serverDomain}" = {
        enableACME = false;
        forceSSL = true;
        sslCertificate = certs."${serverDomain}".cert;
        sslCertificateKey = certs."${serverDomain}".key;

        locations."/" = {
          proxyPass = "http://localhost:3000";
          proxyWebsockets = true;
          extraConfig = ''
            client_max_body_size 150m;
            add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
          '';
        };
      };
    };

    security.pki.certificateFiles = [certs.ca.cert];

    networking.hosts."::1" = ["${serverDomain}"];
    networking.firewall.allowedTCPPorts = [80 443];
  };

  nodes.client = {
    pkgs,
    nodes,
    ...
  }: {
    networking.hosts."${nodes.server.networking.primaryIPAddress}" = ["${serverDomain}"];
    security.pki.certificateFiles = [certs.ca.cert];
  };

  testScript = ''
    server.wait_for_unit("cryptpad.service")
    client.wait_for_unit("multi-user.target")
    client.wait_until_succeeds("curl --fail https://${serverDomain}/")
  '';
}
