{
  description = "haskell.org hoogle deployment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = rec {
          hoogle =
            let
              hsPkgs = pkgs.haskellPackages.override {
                overrides = self: super: {
                  crypton-connection = super.crypton-connection_0_4_3;
                };
              };
            in hsPkgs.callCabal2nix "hoogle" ./. { };
          default = hoogle;
        };
        apps = rec {
          hoogle = flake-utils.lib.mkApp { drv = self.packages.${system}.hoogle; };
          default = hoogle;
        };
      }) // {
        nixosConfigurations."hoogle-test" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            { boot.isContainer = true; }
            (import ./host.nix {
              hoogle = self.packages.x86_64-linux.hoogle;
              domain = "hoogle-test";
              cores = 4;
            })
          ];
        };

        nixosModules.hoogle-haskell-org = { pkgs, ... }: {
          imports = [
            (import ./host.nix {
              hoogle = self.packages.${pkgs.stdenv.hostPlatform.system}.hoogle;
              domain = "hoogle.haskell.org";
              cores = 4;
            })
          ];
        };
      };
}
