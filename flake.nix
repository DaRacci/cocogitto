{
  description = "Cocogitto";

  nixConfig = {
    extra-substituters = [ "https://cachix.cachix.org" ];
    extra-trusted-public-keys = [ "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

    # Currently Darwin cross compilation is broken, so we drop it all together.
    # Following issue: https://github.com/NixOS/nixpkgs/issues/180771
    # Following PR: https://github.com/NixOS/nixpkgs/pull/180931
    systems = { url = "github:nix-systems/default-linux"; };
    flake-utils = { url = "github:numtide/flake-utils"; inputs.systems.follows = "systems"; };

    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    crane = { url = "github:ipetkov/crane"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { nixpkgs, flake-utils, fenix, crane, ... }@inputs:
  flake-utils.lib.eachDefaultSystem (localSystem: let
    pkgs = import nixpkgs { system = localSystem; };

    cargoOutputs = builtins.foldl'
      (attr: crossSystem: attr // (let crate = pkgs.callPackage ./default.nix { inherit localSystem crossSystem flake-utils crane fenix; }; in {
        "${crate.passthru.name}" = crate;
      })) { } [ "x86_64-linux" "x86_64-windows" "aarch64-linux" ];

    # get the native output for the current system, it will be called the crates name.
    nativeOutput = builtins.getAttr "cocogitto" cargoOutputs;
  in {
    packages = builtins.mapAttrs (name: output: output.cargoBuild) cargoOutputs // {
      default = nativeOutput.cargoBuild;
      all-targets = pkgs.symlinkJoin {
        name = "all-targets";
        paths = builtins.attrValues (builtins.mapAttrs (name: outputs: outputs.cargoBuild) cargoOutputs);
      };
    };

    devShells.default = pkgs.callPackage ./shell.nix { inherit pkgs nativeOutput; };

    checks = let name = nativeOutput.passthru.name; in {
      "${name}-formatting" = nativeOutput.cargoFmt;
      "${name}-clippy" = nativeOutput.cargoFmt;
      "${name}-test" = nativeOutput.cargoTest;
    };
  });
}
