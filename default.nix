{ self
, pkgs
, lib
, localSystem
, crossSystem
, flake-utils
, crane
, fenix
}:
let
  # TODO: This is a hack to get the right target for the right system.
  target = let inherit (flake-utils.lib) system; in
    if crossSystem == system.x86_64-linux
    then "x86_64-unknown-linux-gnu"
    else if crossSystem == system.x86_64-darwin
    then "x86_64-apple-darwin"
    else if crossSystem == system.x86_64-windows
    then "x86_64-pc-windows-gnu"
    else if crossSystem == system.aarch64-linux
    then "aarch64-unknown-linux-gnu"
    else if crossSystem == system.aarch64-darwin
    then "aarch64-apple-darwin"
    else abort "Unsupported system";

  toolchain = with fenix.packages.${localSystem}; combine [
    targets.${target}.latest.rust-std
    (stable.withComponents [
      "cargo"
      "rustc"
      "rust-src"
      "clippy-preview"
      "rustfmt-preview"
      "llvm-tools-preview"
    ])
  ];

  craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
  TARGET = (builtins.replaceStrings [ "-" ] [ "_" ] (pkgs.lib.toUpper target));

  crossPackages = let inherit (flake-utils.lib) system; in
    if localSystem == crossSystem
    then pkgs
    else if crossSystem == system.x86_64-linux
    then pkgs.pkgsCross.gnu64
    else if crossSystem == system.x86_64-windows
    then pkgs.pkgsCross.mingwW64
    else if crossSystem == system.aarch64-linux
    then pkgs.pkgsCross.aarch64-multiplatform
    else pkgs.pkgsCross.${crossSystem};

  inherit (crossPackages) targetPlatform;
  isNative = localSystem == crossSystem;
  useMold = isNative && targetPlatform.isLinux;
  useWine = targetPlatform.isWindows && localSystem == flake-utils.lib.system.x86_64-linux;

  commonDeps = {
    depsBuildBuild = [ ]
      ++ lib.optionals (!isNative) (with pkgs; [ qemu ])
      ++ lib.optionals (targetPlatform.isWindows) (with crossPackages; [ stdenv.cc windows.mingw_w64_pthreads windows.pthreads ]);

    buildInputs = with crossPackages; [ openssl ]
      ++ lib.optionals (useMold) (with pkgs; [ clang mold ]);

    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
      openssl
    ]);
  };

  commonEnv = {
    "CARGO_BUILD_TARGET" = target;

    "CARGO_TARGET_${TARGET}_LINKER" =
      if useMold
      then "${crossPackages.clang}/bin/${crossPackages.clang.targetPrefix}clang"
      else let inherit (crossPackages.stdenv) cc; in "${cc}/bin/${cc.targetPrefix}cc";

    "CARGO_TARGET_${TARGET}_RUSTFLAGS" =
      if useMold then "-C link-arg=-fuse-ld=${crossPackages.mold}/bin/mold"
      else null;
  };

  commonArgs =
    let
      cargoToml = craneLib.path ./Cargo.toml;
      src = craneLib.path ./.;

      inherit (craneLib.crateNameFromCargoToml { inherit src cargoToml; }) pname version;
      name = if localSystem == crossSystem then pname else "${pname}-${crossSystem}";

    in
    commonDeps // commonEnv // {
      pname = name;
      inherit src version;

      cargoLock = craneLib.path ./Cargo.lock;
      strictDeps = true;
      doCheck = false; # Checks are done with flake

      # Fixes nix run
      meta.mainProgram = "cog";
    };
in rec {
  passthru = {
    name = commonArgs.pname;
    inherit isNative toolchain commonDeps commonEnv;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  cargoBuild = craneLib.buildPackage (commonArgs // {
    inherit cargoArtifacts;
  });

  cargoClippy = craneLib.cargoClippy (commonArgs // {
    inherit cargoArtifacts;
    cargoClippyExtraArgs = "-- --deny warnings";
  });

  cargoFmt = craneLib.cargoFmt (commonArgs // {
    inherit cargoArtifacts;
  });

  cargoTest = craneLib.cargoNextest (commonArgs // {
    inherit cargoArtifacts;
  });
}
