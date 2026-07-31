{
  description = "Nix package for the official ChatGPT desktop application on Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          chatgptDesktop = pkgs.callPackage ./nix { };
          updater = pkgs.callPackage ./nix/updater.nix { };
          fetchSource = pkgs.writeShellApplication {
            name = "fetch-chatgpt-source";
            runtimeInputs = [ updater ];
            text = ''
              exec update-chatgpt-source --source-dir ${./nix} "$@"
            '';
          };
        in
        {
          default = chatgptDesktop;
          chatgpt-desktop = chatgptDesktop;
          inherit updater;
          fetch-source = fetchSource;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/chatgpt";
        };
        fetch = {
          type = "app";
          program = "${self.packages.${system}.fetch-source}/bin/fetch-chatgpt-source";
        };
      });

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          package = self.packages.${system}.default;
          updater = self.packages.${system}.updater;
          codex-package = pkgs.callPackage ./nix/codex-package.nix { };
          source-metadata =
            pkgs.runCommand "chatgpt-source-metadata-check"
              {
                nativeBuildInputs = [ pkgs.jq ];
              }
              ''
                jq -e \
                  --arg system ${nixpkgs.lib.escapeShellArg system} \
                  '
                    .productId == "9PLM9XGG6VKS"
                    and .identity == "OpenAI.Codex"
                    and .architecture == "x64"
                    and (.version | test("^[0-9]+([.][0-9]+){3}$"))
                    and (.sha256 | startswith("sha256-"))
                    and (.compatibility.codex.version | test("^[0-9]+([.][0-9]+){2}"))
                    and all(
                      .compatibility.codex.bundledX64Sha256[];
                      test("^[0-9a-f]{64}$")
                    )
                    and (.compatibility.codex.packages[$system].target | endswith("-unknown-linux-musl"))
                    and (.compatibility.codex.packages[$system].sha256 | startswith("sha256-"))
                  ' ${./nix/source.json} >/dev/null
                touch "$out"
              '';
          scripts =
            pkgs.runCommand "chatgpt-shell-check"
              {
                nativeBuildInputs = [ pkgs.shellcheck ];
              }
              ''
                shellcheck \
                  ${./nix/update-source.sh} \
                  ${./nix/verify-msix.sh} \
                  ${./scripts/update-source}
                touch "$out"
              '';
        }
      );

      nixosModules.default = import ./nix/nixos-module.nix { inherit self; };
      homeManagerModules.default = import ./nix/home-manager-module.nix { inherit self; };

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
