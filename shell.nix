{ pkgs
, nativeOutput
}: let inherit (nativeOutput.passthru) commonDeps commonEnv toolchain; in (pkgs.mkShell (commonDeps // commonEnv)).overrideAttrs (oldAttrs: {
  nativeBuildInputs = with pkgs; [
    act
    cocogitto
    hyperfine
    cargo-nextest
    toolchain
  ] ++ oldAttrs.nativeBuildInputs or [];
})