{
  description = "aicomiter — Generate conventional Git commit messages with AI (pre-built binaries)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }:
    let
      # -------------------------------------------------------------------
      # Release metadata
      #
      # This flake does NOT build aicomiter from source. Instead, it pulls
      # the pre-built binaries published by goreleaser to GitHub Releases.
      #
      # When bumping the version:
      #   1) update `version` below,
      #   2) refresh every entry in `sources` with the new sha256, e.g.
      #        curl -sL https://github.com/DawnMagnet/aicomiter/releases/download/vX.Y.Z/checksums.txt
      # -------------------------------------------------------------------
      owner = "DawnMagnet";
      repo = "aicomiter";
      version = "0.2.3";

      sources = {
        "x86_64-linux" = {
          asset = "aicomiter_${version}_linux_x86_64.tar.gz";
          sha256 = "a329501e27f37b05b409c0e8f99efc7cc41158d0e46201571d705f0daa808ee0";
        };
        "aarch64-linux" = {
          asset = "aicomiter_${version}_linux_arm64.tar.gz";
          sha256 = "093b43beb314b269dab623ebd0171843f5d241671beeacc5c1f9b0e39299089b";
        };
        "x86_64-darwin" = {
          asset = "aicomiter_${version}_macOS_x86_64.tar.gz";
          sha256 = "221a3bb4938a2967198a6785e318146a64c3a9b97e1afab778e0cdb440553f9e";
        };
        "aarch64-darwin" = {
          asset = "aicomiter_${version}_macOS_arm64.tar.gz";
          sha256 = "e2172c884c2ea71cce9403cb1efaf47acde2d0bf572e8c1b94dd973712a1d590";
        };
      };

      # Systems we ship pre-built binaries for. Kept as a stable list
      # regardless of what the currently-locked nixpkgs supports, so the
      # overlay stays usable with older nixpkgs pins.
      supportedSystems = builtins.attrNames sources;

      # Systems iterated when producing per-system flake outputs
      # (`packages`, `apps`). We drop platforms that recent nixpkgs
      # branches no longer support (e.g. `x86_64-darwin` is unsupported
      # by nixpkgs ≥ 26.11); consumers on those platforms can still
      # obtain the package via `overlays.default` on top of a compatible
      # nixpkgs pin.
      flakeSystems = builtins.filter (
        s: !(builtins.elem s [ "x86_64-darwin" ])
      ) supportedSystems;

      # Build a derivation that just unpacks the release tarball and
      # installs the binary. Linux artifacts are static musl builds and
      # need no ELF patching; macOS artifacts are native Mach-O binaries.
      mkPackage =
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          src =
            sources.${system}
              or (throw "aicomiter: no pre-built binary for system ${system}");
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "aicomiter";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/${owner}/${repo}/releases/download/v${version}/${src.asset}";
            sha256 = src.sha256;
          };

          sourceRoot = ".";

          # We just unpack a release tarball; no configure/build steps.
          dontConfigure = true;
          dontBuild = true;
          # The binaries ship pre-stripped and, on macOS, ad-hoc signed.
          # Touching them would invalidate the signature and prevent
          # execution, so leave them exactly as published.
          dontStrip = true;
          dontPatchELF = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 aicomiter "$out/bin/aicomiter"
            for doc in README.md USAGE.md LICENSE; do
              if [ -f "$doc" ]; then
                install -Dm644 "$doc" "$out/share/doc/aicomiter/$doc"
              fi
            done
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Generate conventional Git commit messages with AI";
            homepage = "https://github.com/${owner}/${repo}";
            license = licenses.mit;
            platforms = supportedSystems;
            mainProgram = "aicomiter";
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
          };
        };

      overlay = final: prev: {
        aicomiter = mkPackage final;
      };
    in
    (flake-utils.lib.eachSystem flakeSystems (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        aicomiter = mkPackage pkgs;
      in
      {
        packages = {
          default = aicomiter;
          aicomiter = aicomiter;
        };

        apps.default = {
          type = "app";
          program = "${aicomiter}/bin/aicomiter";
          meta = aicomiter.meta;
        };
      }
    ))
    // {
      overlays.default = overlay;

      # NixOS module: `programs.aicomiter.enable = true;`
      nixosModules.default =
        { pkgs, lib, config, ... }:
        let
          cfg = config.programs.aicomiter;
        in
        {
          options.programs.aicomiter = {
            enable = lib.mkEnableOption "aicomiter, an AI-powered git commit message generator";

            package = lib.mkOption {
              type = lib.types.package;
              default = mkPackage pkgs;
              defaultText = lib.literalExpression "aicomiter.packages.\${system}.default";
              description = "The aicomiter package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      # Home-Manager module: `programs.aicomiter.enable = true;`
      # Additionally supports declaratively managing `~/.aicomiter.yaml`
      # via `programs.aicomiter.settings`.
      #
      # Exposed under both the legacy (`homeManagerModules`) and the
      # newer (`homeModules`) convention for maximum compatibility.
      homeManagerModules.default = self.homeModules.default;

      homeModules.default =
        { pkgs, lib, config, ... }:
        let
          cfg = config.programs.aicomiter;
          package = cfg.package;
        in
        {
          options.programs.aicomiter = {
            enable = lib.mkEnableOption "aicomiter, an AI-powered git commit message generator";

            package = lib.mkOption {
              type = lib.types.package;
              default = mkPackage pkgs;
              defaultText = lib.literalExpression "aicomiter.packages.\${system}.default";
              description = "The aicomiter package to install.";
            };

            settings = lib.mkOption {
              type = with lib.types; nullOr (attrsOf anything);
              default = null;
              example = lib.literalExpression ''
                {
                  ai = {
                    provider = "openai";
                    # Choose exactly one credential source:
                    # api_key = "sk-...";
                    api_key_env = "OPENAI_API_KEY";
                    # api_key_file = "/run/secrets/openai_api_key";
                    model = "gpt-4o-mini";
                    temperature = 0.4;
                  };
                  generate = {
                    language = "en";
                    count = 1;
                  };
                }
              '';
              description = ''
                Contents written to `~/.aicomiter.yaml`. For AI credentials,
                choose exactly one of `ai.api_key`, `ai.api_key_env`, or
                `ai.api_key_file`. Set to `null` (default) to leave the
                configuration file unmanaged so it can be edited by hand or
                via `aicomiter config`.
              '';
            };
          };

          config = lib.mkIf cfg.enable (lib.mkMerge [
            { home.packages = [ package ]; }
            (lib.mkIf (cfg.settings != null) {
              home.file.".aicomiter.yaml".source =
                (pkgs.formats.yaml { }).generate "aicomiter.yaml" cfg.settings;
            })
          ]);
        };

      # Expose the raw builder so downstream flakes can compose their own
      # package attribute (e.g. pinning to a different nixpkgs).
      lib = {
        inherit mkPackage;
        supportedSystems = supportedSystems;
      };
    };
}
