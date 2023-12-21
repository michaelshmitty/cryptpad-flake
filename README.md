# About this flake

This Nix flake packages [Cryptpad](https://cryptpad.org/), a collaborative office suite that is end-to-end encrypted and open-source.

# Usage

With this flake you can deploy Cryptpad on NixOS. You can use the `cryptpad` module available in `.#nixosModules`.

## Using flakes

### Add from GitHub

```nix
{
  description = "Nix flake for my infrastructure";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-23.11";
    };

    cryptpad = {
      url = "github:michaelshmitty/cryptpad-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, cryptpad }@inputs: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ inputs.cryptpad.overlays.default ];
        })
        inputs.cryptpad.nixosModules.cryptpad
        ./configuration.nix
      ];
    };
  };
}
```

### Add from FlakeHub

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/michaelshmitty/cryptpad/badge)](https://flakehub.com/flake/michaelshmitty/cryptpad)

Add the cryptpad flake to your `flake.nix`:

```nix
{
  inputs.cryptpad.url = "https://flakehub.com/f/michaelshmitty/cryptpad/*.tar.gz";

  outputs = { self, cryptpad }: {
    # Use in your outputs
  };
}

```

## Configure

Now that you have the module available, configuration is straightforward. See example `configuration.nix`:

```nix
{ pkgs, lib, config, ... }:

{
  services.cryptpad = {
    enable = true;
    configureNginx = true;
    settings = {
      httpUnsafeOrigin = "https://cryptpad.example.com";
      httpSafeOrigin = "https://cryptpad-ui.example.com";

      # Add this after you've signed up in your Cryptpad instance and copy your public key:
      adminKeys = [ "[user@cryptpad.example.com/Jil1apEPZ40j5M8nsjO1-deadbeefHkt+QExscMzKhs=]" ];
    };
  };
}
```

Deploy and check your Cryptpad setup at `https://<domain>/checkup`

# Run tests
This flake contains a simple integration test that will spin up a server NixOS container that will build and
run Cryptpad and Nginx. And a client NixOS container that will test connectivity to the Cryptpad instance.

Execute `nix flake check` in this repository to run the integration test.

# Adding Cryptpad to nixpkgs

There is [an active, open PR](https://github.com/NixOS/nixpkgs/pull/251687) to add Cryptpad back to nixpkgs. I am
contributing my work on this flake into that PR.
