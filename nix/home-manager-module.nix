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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
