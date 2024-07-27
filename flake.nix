{
  description = "basic flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flakery.url = "github:getflakery/flakes";
  inputs.comin.url = "github:r33drichards/comin/9b7229c06efddb0911e00e0934aa472665dcb649";


  outputs = { self, nixpkgs, flake-utils, flakery, comin, ... }@inputs:
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          devshell = pkgs.mkShell {
            buildInputs = with pkgs; [
              terraform 
              awscli2
            ];
          };

        in
        {
          packages.nixosConfigurations.flakery = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              inputs.comin.nixosModules.comin
              flakery.nixosModules.flakery
              flakery.nixosConfigurations.base
              ./configuration.nix
            ];
          };
          devShells.default = devshell;

        })
    );
}
