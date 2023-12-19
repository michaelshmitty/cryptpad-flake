# cryptpad-flake

This [Nix flake](https://nixos.wiki/wiki/Flakes) provides a Nix package and NixOS module for
[Cryptpad](https://cryptpad.org/).

The NixOS module targets the latest release of NixOS. That’s 23.11.

## Notes

* This flake was inspired by https://github.com/reckenrode/nix-foundryvtt and
  [Installing Flakes into a NixOS 22.11 System](https://falconprogrammer.co.uk/blog/2023/02/nixos-22-11-flakes/).
* There is [an active, open PR](https://github.com/NixOS/nixpkgs/pull/251687) to add Cryptpad back into nixpkgs.
  I am contributing on there but I found it hard to test and iterate quickly with my infrastructure running on flakes.
  The idea is to offer my implementation here to the PR and get Cryptpad back into
  [nixpkgs](https://github.com/NixOS/nixpkgs).

## How to use it

1. Add this flake as an input to your flake

```nix
{
  description = "Nix flake for my infrastructure";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-23.11";
    };

    # Other inputs ...

    cryptpad = {
      url = "github:michaelshmitty/cryptpad-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

2. In your configuration.nix for hostname put

```nix
{ inputs, ... }:
{
  imports = [ inputs.cryptpad.nixosModules.cryptpad ];

  services.cryptpad = {
    enable = true;
    configureNginx = true;
    config = {
      httpUnsafeOrigin = "https://cryptpad.example.com";
      httpSafeOrigin = "https://cryptpad-ui.example.com";

      # Add this after you've signed up in your Cryptpad instance and copy your public key:
      adminKeys = [ "[user@cryptpad.example.com/Jil1apEPZ40j5M8nsjO1-deadbeefHkt+QExscMzKhs=]" ];
    };
  };
}
```

3. Deploy your configuration and enjoy Cryptpad at the configured URL!
