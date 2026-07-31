{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
  gzip,
  jq,
  runCommand,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  system = stdenvNoCC.hostPlatform.system;
  codex = source.compatibility.codex;
  package =
    codex.packages.${system} or (throw "ChatGPT Desktop has no Codex helper package for ${system}");
  archiveName = "codex-package-${package.target}.tar.gz";
in
runCommand "chatgpt-codex-package-${codex.version}-${system}"
  {
    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codex.version}/${archiveName}";
      hash = package.sha256;
    };
    nativeBuildInputs = [
      gnutar
      gzip
      jq
    ];
    passthru = {
      inherit (codex) version;
      inherit (package) target;
    };
    meta = {
      description = "Version-matched official Codex helpers for ChatGPT Desktop";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  ''
    mkdir -p "$out"
    tar -xzf "$src" -C "$out"

    jq -e \
      --arg version ${lib.escapeShellArg codex.version} \
      --arg target ${lib.escapeShellArg package.target} \
      '.version == $version and .target == $target' \
      "$out/codex-package.json" >/dev/null

    for helper in bin/codex bin/codex-code-mode-host codex-path/rg; do
      test -x "$out/$helper"
    done
  ''
