{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flakery.url = "github:getflakery/flakes";
    comin.url = "github:r33drichards/comin/72a6e4b9fa29171fffa372ef30ef5ff06850d09f";

    
  };

  outputs = { self, nixpkgs, flakery }: {
    nixosConfigurations.flakery = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.comin.nixosModules.comin
        flakery.nixosModules.flakery
        flakery.nixosConfigurations.base
        ./configuration.nix
      ];
    };
  };
}