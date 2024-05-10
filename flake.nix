{
  description = "NixOS RKE2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs self.lib.supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      lib.supportedSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      packages = eachSystem (pkgs: {
        # Re-export rke2 from nixpkgs, for good measure
        default = pkgs.rke2;
      });

      nixosModules.default = import ./modules/nixos/rke2;
    };
}
