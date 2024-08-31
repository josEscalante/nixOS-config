{
  # Repos n shit
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05"; # actualizar esto para actualizar
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    nixGL.url = "github:guibou/nixGL";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05"; # actualizar esto para actualizar
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Configuraciones
  outputs = flakes@{
    self,
    nixpkgs,
    unstable,
    home-manager,
    nur,
    nixGL,
    ...
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
    };

    inherit (pkgs) lib;

    sys = platform: {
      name = platform;
      value = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [(import ./sys)];
      };
    };

    home = platform: {
      name = "chem@${platform}";
      value = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          (import ./home {
            inherit self nixpkgs unstable nixGL;
          })

          ./home/platforms/${platform}.nix

          {
            config.local = {inherit platform;};
          }
        ];
      };
    };

    localPkgs = import ./pkgs;

    platforms = domain:
      map
      (lib.removeSuffix ".nix")
      (lib.attrNames (builtins.readDir ./${domain}/platforms));

    configs = domain: builder:
      lib.listToAttrs
      (map builder (platforms domain));
  in 
with pkgs.lib;
{
    packages.${system} = localPkgs pkgs;
    formatter.${system} = pkgs.alejandra;

      nixosConfigurations =
        let
          nixosSystem = { modules }: makeOverridable nixpkgs.lib.nixosSystem {
            inherit modules pkgs system;

            specialArgs = {
              inherit flakes;
            };
          };

          hostConfig = main: nixosSystem {
            modules = [
              ./sys
              main
            ];
          };
        in
        mapAttrs (_: hostConfig) (importAll { root = ./sys/platforms; });

      homeConfigurations =
        let
          registry = { ... }: {
            config.nix.registry = mapAttrs
              (_: value: {
                flake = value;
              })
              flakes;
          };

          home = platform: home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            modules = [
              ./home
              platform
              registry
            ];
          };

          platformHome = name: platform:
            let
              value = home platform;
            in
            {
              inherit name value;
            };
        in
        mapAttrs' platformHome (importAll { root = ./home/platforms; });
    };
}
