{
  description = ''
    CryptPad is a collaborative office suite that is end-to-end encrypted and open-source.
  '';

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      darwin = [ "x86_64-darwin" "aarch64-darwin" ];
      linux = [ "x86_64-linux" "aarch64-linux" ];

      forEachSystem = systems: f: lib.genAttrs systems (system: f system);
      forAllSystems = forEachSystem (darwin ++ linux);
    in
    {
      nixosModules.cryptpad = import ./modules/cryptpad self;
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          cryptpad = pkgs.callPackage ./pkgs/cryptpad { };
          default = self.packages.${system}.cryptpad;
        });
    };
}
