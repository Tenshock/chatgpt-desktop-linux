{
  callPackage,
  asar,
  coreutils,
  curl,
  gawk,
  gnugrep,
  jq,
  libxml2,
  nix,
  openssl,
  osslsigncode,
  unzip,
  writeShellApplication,
}:

let
  roots = callPackage ./microsoft-roots.nix { };
  storelib-rs = callPackage ./storelib-rs.nix { };
  verifier = writeShellApplication {
    name = "verify-chatgpt-msix";
    runtimeInputs = [
      asar
      coreutils
      gnugrep
      libxml2
      openssl
      osslsigncode
      unzip
    ];
    text = builtins.readFile ./verify-msix.sh;
  };
in
writeShellApplication {
  name = "update-chatgpt-source";
  runtimeInputs = [
    coreutils
    curl
    gawk
    gnugrep
    jq
    nix
    storelib-rs
    verifier
  ];
  text = ''
    export CHATGPT_MICROSOFT_ROOT_2010=${roots.root2010}
    export CHATGPT_MICROSOFT_ROOT_2011=${roots.root2011}
    export CHATGPT_STORE_CA_BUNDLE=${storelib-rs}/etc/ssl/certs/storelib-ca-bundle.crt
    ${builtins.readFile ./update-source.sh}
  '';
}
