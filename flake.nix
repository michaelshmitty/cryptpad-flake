{
  description = ''
    Package and module for CryptPad, a collaborative office suite that is end-to-end encrypted and open-source.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          packages = {
            default = self.packages.${system}.cryptpad;

            cryptpad = pkgs.buildNpmPackage rec {
              pname = "cryptpad";
              version = "5.6.0";

              src = pkgs.fetchFromGitHub {
                owner = "cryptpad";
                repo = "cryptpad";
                rev = version;
                hash = "sha256-A3tkXt4eAeg1lobCliGd2PghpkFG5CNYWnquGESx/zo=";
              };

              npmDepsHash = "sha256-tQUsI5Oz3rkAlxJ1LpolJNqZfKUGKUYSgtuCTzHRcW4=";

              makeCacheWritable = true;

              patches = [
                # Fix how safe/unsafe port configuration is handled.
                # Reported as https://github.com/cryptpad/cryptpad/pull/1212
                ./0001-correctly-listen-to-httpSafePort.patch
              ];

              dontNpmInstall = true;

              installPhase = ''
                out_cryptpad="$out/lib/node_modules/cryptpad"

                mkdir -p "$out_cryptpad"
                cp -r . "$out_cryptpad"

                # Cryptpad runs in its source directory. This wrappers enables keeping the Cryptpad source code
                # in the nix store while still having writeable paths for storing state.
                # The 'customize' directory maintains customizations, so don't link it if it is a directory.
                makeWrapper ${pkgs.nodejs}/bin/node $out/bin/cryptpad \
                  --add-flags "$out_cryptpad/server.js" \
                  --run "for d in customize.dist lib www; do ln -sf $out_cryptpad/\$d .; done" \
                  --run "if ! [ -e customize ] || [ -L customize ]; then ln -sf $out_cryptpad/customize .; fi"

                # Cryptpad also expects www/components to link to node_modules
                ln -s ../node_modules "$out_cryptpad/www/components"
              '';

              meta = with pkgs.lib; {
                description = "A collaborative office suite that is end-to-end encrypted and open-source";
                homepage = "https://cryptpad.org/";
                license = licenses.agpl3Only;
                maintainers = with maintainers; [ michaelshmitty ];
                mainProgram = "cryptpad";
              };
            };
          };

          checks = {
            integrationTest =
              let
                # Evaluate nixpkgs again because pkgs doesn't contain the cryptpad package and module.
                pkgsCryptpad = import nixpkgs {
                  inherit system;
                  overlays = [ self.overlays.default ];
                };
              in
              pkgsCryptpad.nixosTest (import ./integration-test.nix {
                inherit nixpkgs;
                cryptpadModule = self.nixosModules.cryptpad;
              });
            package = self.packages.${system}.cryptpad;
          };
        }) // {
      nixosModules.cryptpad = import ./module.nix;

      overlays.default = final: prev: {
        inherit (self.packages.${prev.system}) cryptpad;
      };
    };
}
