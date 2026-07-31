{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.chatgptDesktop;
  system = pkgs.stdenv.hostPlatform.system;
  configuredPackage =
    if cfg.githubTokenCommand == null then
      cfg.package
    else
      cfg.package.override {
        inherit (cfg) githubTokenCommand;
      };
in
{
  options.programs.chatgptDesktop = {
    enable = lib.mkEnableOption "ChatGPT Desktop for Linux";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.default;
      defaultText = lib.literalExpression "inputs.chatgpt-desktop-linux.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "ChatGPT Desktop package to install.";
    };

    githubTokenCommand = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.addCheck (lib.types.listOf lib.types.str) (command: command != [ ])
      );
      default = null;
      example = [
        "/run/wrappers/bin/op"
        "read"
        "op://Vault/GitHub/token"
      ];
      description = ''
        Optional command whose standard output is provided to ChatGPT as
        GH_TOKEN. Arguments are executed directly without a shell. Never put
        a literal token in Nix configuration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ configuredPackage ];
  };
}
