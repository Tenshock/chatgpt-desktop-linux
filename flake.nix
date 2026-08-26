{
  description = "Nix package for OpenAI's official ChatGPT desktop application for Linux";

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
        in
        {
          default = chatgptDesktop;
          chatgpt-desktop = chatgptDesktop;
          updater = pkgs.callPackage ./nix/updater.nix { };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/chatgpt";
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
          source-metadata =
            pkgs.runCommand "chatgpt-source-metadata-check"
              {
                nativeBuildInputs = [ pkgs.jq ];
              }
              ''
                jq -e \
                  --arg system ${nixpkgs.lib.escapeShellArg system} \
                  '
                    (.version | test("^[0-9]+([.][0-9]+)+$"))
                    and (.packages | keys | sort == ["aarch64-linux", "x86_64-linux"])
                    and (.packages[$system].architecture == (
                      if $system == "x86_64-linux" then "amd64" else "arm64" end
                    ))
                    and (.packages[$system].url | test(
                      "^https://persistent[.]oaistatic[.]com/codex-app-prod/linux/deb/"
                    ))
                    and (.packages[$system].hash | startswith("sha256-"))
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
