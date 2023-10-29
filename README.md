# Nix packaging: RKE2

> NOTE: this is a work in progress

RKE2, also known as RKE Government, is Rancher's next-generation Kubernetes distribution.

The rke2 package is already in nixpkgs. 

This repository provides the NixOS module for it.

## Usage (using Flakes)

To add the program to your flake, add the following input:

```nix
inputs = {
  rke2.url = "git.numtide.com/nix-packaging/rke2";
}
```

## NixOS module

TODO

## Supported platforms

* x86_64-linux

## Missing features

The module is still very barebones.

* Add documentation
* Add NixOS VM test
* Add airgap/offline mode

## Copyright

MIT

Brought to you by the team of <https://nix-packaging.com>.

