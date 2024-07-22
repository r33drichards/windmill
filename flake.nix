{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flakery.url = "github:getflakery/flakes";
    comin.url = "github:r33drichards/comin/4289478d4bfb60ea30cf6db7628b5a1547313bb3";

    
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