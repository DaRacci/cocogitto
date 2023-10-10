{ pkgs
, nativeOutput
}: let inherit (nativeOutput.passthru) commonDeps commonEnv toolchain; in (pkgs.mkShell (commonDeps // commonEnv)).overrideAttrs (oldAttrs: {
  nativeBuildInputs = with pkgs; [
    act
    hyperfine
    toolchain
    nativeOutput.cargoBuild
    cargo-nextest
    cargo-llvm-cov
  ] ++ oldAttrs.nativeBuildInputs or [];
})
