{
  description = "Instant, easy, and predictable development environments.";

  outputs = { self, nixpkgs }:
    let
      commit = self.rev or self.dirtyRev or "";
      commitDate = self.lastModifiedDate or "";

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = f: builtins.listToAttrs (map (system: { "name" = system; "value" = (f system); }) systems);

      overlays = [
        (final: prev: {
          go = prev.go_1_21;
          buildGoModule = prev.buildGo121Module;
        })
      ];
    in
    {
      packages = forEachSystem (system:
        let
          pkgs = import nixpkgs { inherit system overlays; };
        in
        {
          default = pkgs.buildGoModule rec {
            name = "devbox";
            src = ./.;
            doCheck = false;
            subPackages = [ "cmd/devbox" ];
            CGO_ENABLED = 0;

            ldflags = [
              "-s"
              "-w"
              "-extldflags=-static"
              "-X go.jetpack.io/devbox/internal/build.Commit=${commit}"
              "-X go.jetpack.io/devbox/internal/build.CommitDate=${commitDate}"

              # There doesn't seem to be a good way of getting the version tag
              # because the git repo is unavailable at build time. We probably
              # need to write the version to a committed file or something.
              "-X go.jetpack.io/devbox/internal/build.Version=flake-${commit}"

              # Same with secrets. These values aren't really secrets though.
              # Could we just hardcode them in the source instead?
              # "-X go.jetpack.io/devbox/internal/build.SentryDSN=$SENTRY_DSN"
              # "-X go.jetpack.io/devbox/internal/build.TelemetryKey=$TELEMETRY_KEY"
            ];

            # This changes whenever go.mod dependencies change. To get the new
            # hash, run `nix build` and copy/paste the expected hash from the
            # error message here.
            vendorHash = "sha256-fDh+6aBrHUqioNbgufFiD5c4i8SGAYrUuFXgTVmhrRE=";

            # Adds installShellCompletion used in the postInstall phase below.
            nativeBuildInputs = [ pkgs.installShellFiles ];

            postInstall = ''
              installShellCompletion --cmd devbox \
                --bash <($out/bin/devbox completion bash) \
                --fish <($out/bin/devbox completion fish) \
                --zsh <($out/bin/devbox completion zsh)
            '';
          };
        }
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
