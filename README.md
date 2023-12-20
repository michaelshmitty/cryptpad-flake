# About this flake

This Nix flake packages [Cryptpad](https://cryptpad.org/), a collaborative office suite that is end-to-end encrypted and open-source.

# Usage

The primary use of this flake is deploying Cryptpad on NixOS. For that you would use the NixOS module available in `.#nixosModule`.

## Using flakes
1. Add this flake as an input

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


2. Now that you have the module available as an input, configuration is straightforward. See example:

```nix
{ inputs, ... }: {

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

3. Deploy and check your Cryptpad setup at `https://<domain>/checkup`

# Putting Cryptpad into Nixpkgs

There is [an active, open PR](https://github.com/NixOS/nixpkgs/pull/251687) to add Cryptpad back into nixpkgs. I am
contributing to that PR as well, but I found it hard to test and iterate quickly using my NixOS flake configuration.
