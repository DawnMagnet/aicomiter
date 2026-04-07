{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenv.mkDerivation {
  pname = "aicomiter";
  version = "0.1.0";

  # 将当前目录作为源码目录，忽略构建产生的缓存文件和 git 数据
  src = pkgs.lib.cleanSource ./.;

  nativeBuildInputs = [
    pkgs.zig
    pkgs.upx
  ];

  # Zig 不依赖 autotools 的 configure
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # 隔离 Nix 沙盒环境下的缓存，防止 permission denied 或因为无 HOME 目录报错
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache

    # 使用 ReleaseSafe 优化构建，并将它直接安装到 Nix 构建输出目录的 $out，
    # 其中 --prefix $out 会自动创建 $out/bin 并放入生成的可执行文件。
    zig build -Doptimize=ReleaseSmall --prefix $out

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # 安装阶段留空，因为在 buildPhase 中传入的 --prefix $out 已经把可执行文件直接拷贝就位了
    runHook postInstall
  '';

  # 在 Nix 的默认 strip 剥离完符号信息之后再执行 upx 压缩，避免默认的 strip 破坏 upx 压缩壳
  postFixup = ''
    upx --best $out/bin/aicomiter
  '';

  meta = with pkgs.lib; {
    description = "AI Git Commit Message Generator";
    platforms = platforms.unix;
  };
}
