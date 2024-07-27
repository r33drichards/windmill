{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flakery.url = "github:getflakery/flakes";
    comin.url = "github:r33drichards/comin/9b7229c06efddb0911e00e0934aa472665dcb649";

    
  };

  outputs = { self, nixpkgs, flakery, comin }@inputs: {
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