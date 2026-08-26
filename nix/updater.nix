{
  coreutils,
  curl,
  dpkg,
  gawk,
  gnupg,
  gzip,
  jq,
  nix,
  writeShellApplication,
}:

writeShellApplication {
  name = "update-chatgpt-source";
  runtimeInputs = [
    coreutils
    curl
    dpkg
    gawk
    gnupg
    gzip
    jq
    nix
  ];
  text = ''
    export CHATGPT_REPOSITORY_KEY=${./openai-linux-repository.asc}
    ${builtins.readFile ./update-source.sh}
  '';
}
