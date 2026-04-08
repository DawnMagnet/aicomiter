{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenv.mkDerivation {
  pname = "aicomiter";
  version = "0.1.0";

  # Use a cleaned working tree as source to avoid cache and VCS noise.
  src = pkgs.lib.cleanSource ./.;

  nativeBuildInputs = [
    pkgs.zig
    pkgs.upx
  ];

  # Zig build does not require a configure phase.
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # Isolate Zig caches in the sandbox to avoid HOME/permission issues.
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache

    # Build with ReleaseSmall and install directly into $out.
    # --prefix $out ensures the binary is placed under $out/bin.
    zig build -Doptimize=ReleaseSmall --prefix $out

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Keep install phase empty because build phase already installed outputs.
    runHook postInstall
  '';

  # Run upx after default strip to avoid breaking the compressed binary.
  postFixup = ''
    upx --best $out/bin/aicomiter
  '';

  meta = with pkgs.lib; {
    description = "AI Git Commit Message Generator";
    platforms = platforms.unix;
  };
}
