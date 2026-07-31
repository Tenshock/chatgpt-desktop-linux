{
  lib,
  cacert,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  openssl,
  pkg-config,
  rustPlatform,
}:

let
  microsoftRoot2011 = fetchurl {
    url = "https://www.microsoft.com/pki/certs/MicRooCerAut2011_2011_03_22.crt";
    hash = "sha256-hH32p4SXlD8n/HLrk/mmNzIKArVh0KkbCeh6eAftfGE=";
  };
in

rustPlatform.buildRustPackage {
  pname = "storelib-rs";
  version = "0.1.11-fix-1";

  src = fetchFromGitHub {
    owner = "query-store-links";
    repo = "storelib_rs";
    rev = "7639d7a86b4eca85dbcf138844d082ae9c1c4313";
    hash = "sha256-xdlCwG+uPUWsUEL0/AewgR2O4KHrIPww4zqEAxV09h4=";
  };

  cargoHash = "sha256-95BUFQrBdZC6NQREbaqgJEhGgH5Ktho6J1+26uUKwwM=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];
  buildInputs = [ openssl ];

  doCheck = false;

  postFixup = ''
    install -Dm644 ${cacert}/etc/ssl/certs/ca-bundle.crt \
      "$out/etc/ssl/certs/storelib-ca-bundle.crt"
    chmod u+w "$out/etc/ssl/certs/storelib-ca-bundle.crt"
    ${openssl}/bin/openssl x509 -inform DER \
      -in ${microsoftRoot2011} \
      -out "$out/etc/ssl/certs/microsoft-root-2011.pem"
    sed -n '1,$p' "$out/etc/ssl/certs/microsoft-root-2011.pem" \
      >> "$out/etc/ssl/certs/storelib-ca-bundle.crt"

    wrapProgram "$out/bin/storelib_rs" \
      --set SSL_CERT_FILE "$out/etc/ssl/certs/storelib-ca-bundle.crt"
  '';

  meta = {
    description = "Microsoft Store API client used by the ChatGPT source updater";
    homepage = "https://github.com/query-store-links/storelib_rs";
    license = lib.licenses.gpl3Only;
    mainProgram = "storelib_rs";
    platforms = lib.platforms.linux;
  };
}
