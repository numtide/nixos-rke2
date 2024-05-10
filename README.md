# NixOS RKE2

RKE2 is Rancher's next-generation Kubernetes distribution. It is a fully conformant Kubernetes distribution that focuses on security and compliance within the U.S. Federal Government and other regulated industries.

NixOS is a Linux distribution that is declaratively configured using the Nix package manager. It is a great fit for running Kubernetes clusters, as it allows for easy and reproducible cluster deployments.

This repository contains a NixOS module for deploying RKE2 on NixOS. We are using it in a couple of places and it's stable, but not yet fully tested and documented.

## Quick usage

First, add this project to your flake inputs:

```nix
inputs = {
  rke2.url = "github:numtide/nixos-rke2";
}
```

Then configure your master node like this (single-node deployment):

```nix
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.rke2.nixosModules.default
  ];

  # Don't interfere with k8s
  networking.firewall.enable = lib.mkForce false;

  services.rke2 = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable"
      "rke2-ingress-nginx"
    ];
    settings.kube-apiserver-arg = [ "anonymous-auth=false" ];
    settings.tls-san = [ "<TODO>" ];
    settings.write-kubeconfig-mode = "0644";
  };
}
```

Once deployed, get the RKE2 join token by SSH-into to the master node and running:

```sh
rke2 token create
```

Stick the token in a file and encrypt it with SOPS. Then deploy your workers:

```nix
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.rke2.nixosModules.default
  ];

  # Don't interfere with k8s
  networking.firewall.enable = lib.mkForce false;

  services.rke2 = {  
    enable = true;                                                         
    role = "agent";                                                           
    serverAddr = "https://<TODO>:9345";                                    
    tokenFile = config.sops.secrets.rke2-worker-token.path;                   
  };
```

## Supported platforms

* x86_64-linux

## Missing features

The module is still very barebones.

* Add more documentation and use-cases.
* Add NixOS VM test
* Add airgap/offline mode

## Copyright

MIT

Brought to you by Numtide, the open-source specialists. [Ping us](https://numtide.com/contact) if you need feature development or help.
