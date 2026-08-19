{
  description = "ferric-fred — a strongly-typed Rust client for FRED, plus a CLI and MCP server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";

    # vale, for the prose gate (ADR-0031), pinned to its own nixpkgs revision:
    # this rev supplies vale 3.17.1, the version ~/.claude's own CI pins and the
    # version the shared rules were measured against. A separate input keeps the
    # prose gate's version decoupled from Rust-toolchain nixpkgs bumps — the main
    # input currently carries vale 3.15.1, and bumping it for vale alone would
    # move the compiler too.
    nixpkgs-vale.url = "github:NixOS/nixpkgs/0ae2bc1419c3f345984c2629e72e7a631820fa4d";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-vale,
      rust-overlay,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # See the `nixpkgs-vale` input: vale 3.17.1, pinned apart from the
        # toolchain.
        vale = nixpkgs-vale.legacyPackages.${system}.vale;

        # Recent stable toolchain (ADR-0007: track stable, no pinned MSRV yet).
        # Components cover editor + lint/format tooling out of the box.
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "clippy"
            "rustfmt"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          # No OpenSSL / pkg-config here on purpose: ADR-0003 chose rustls-tls,
          # so the HTTP stack has no system TLS dependency.
          packages = [
            rustToolchain
            pkgs.cargo-nextest
            pkgs.cargo-deny
            pkgs.bacon # background `cargo check`/clippy/test runner
            pkgs.infisical # CLI: inject secret values (e.g. FRED_API_KEY) via direnv
            pkgs.gitleaks # secret scanner for the pre-commit guard (.githooks/pre-commit)
            pkgs.hyperfine # CLI wall-clock timing for scripts/bench-cli.sh (perf pilot — issue #42)
            vale # prose linter for the shared house style (ADR-0031)
          ];

          env.RUST_BACKTRACE = "1";

          shellHook = ''
            echo "ferric-fred dev shell — $(rustc --version)"
          '';
        };

        # `nix fmt` formats the Nix files in this repo.
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
