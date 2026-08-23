{
  lib,
  stdenv,
  autoPatchelfHook,
  buildNpmPackage,
  electron_42,
  libusb1,
  pkg-config,
  python3,
  systemdLibs,
  systemdMinimal,
}:

let
  source = builtins.fromJSON (builtins.readFile ../source.json);
  npmArch =
    if stdenv.hostPlatform.isx86_64 then
      "x64"
    else if stdenv.hostPlatform.isAarch64 then
      "arm64"
    else
      throw "ChatGPT Desktop native modules do not support ${stdenv.hostPlatform.system}";
  watcherPackage = "@parcel/watcher-linux-${npmArch}-glibc";
in
buildNpmPackage {
  pname = "chatgpt-desktop-native-modules";
  inherit (source) version;

  src = ./.;
  npmDepsHash = "sha256-AjozmsePzT7yyzL5G/w0S7eiHbc84u6Fc13P7Ya7j0M=";
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
    python3
    systemdMinimal
  ];

  buildInputs = [
    libusb1
    stdenv.cc.cc.lib
    systemdLibs
  ];

  env = {
    npm_config_build_from_source = "true";
    npm_config_arch = npmArch;
    npm_config_nodedir = electron_42.headers;
    npm_config_runtime = "electron";
    npm_config_target = electron_42.version;
  };

  buildPhase = ''
    runHook preBuild

    patch -d node_modules/better-sqlite3 -p1 \
      < ${./better-sqlite3-electron-42.patch}

    rm -rf \
      node_modules/better-sqlite3/build \
      node_modules/node-pty/build \
      node_modules/node-hid/build \
      node_modules/@serialport/bindings-cpp/build

    export npm_config_build_from_source=true
    export npm_config_arch=${npmArch}
    export npm_config_nodedir=${electron_42.headers}
    export npm_config_runtime=electron
    export npm_config_target=${electron_42.version}

    npm rebuild \
      better-sqlite3 \
      node-pty \
      node-hid \
      @serialport/bindings-cpp

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 \
      node_modules/better-sqlite3/build/Release/better_sqlite3.node \
      "$out/better-sqlite3/better_sqlite3.node"
    install -Dm755 \
      node_modules/node-pty/build/Release/pty.node \
      "$out/node-pty/pty.node"
    install -Dm755 \
      node_modules/node-hid/build/Release/HID.node \
      "$out/node-hid/HID.node"
    install -Dm755 \
      node_modules/@serialport/bindings-cpp/build/Release/bindings.node \
      "$out/serialport/bindings.node"

    mkdir -p "$out/parcel-watcher/node_modules/@parcel"
    cp -R \
      node_modules/@parcel/watcher \
      node_modules/${watcherPackage} \
      "$out/parcel-watcher/node_modules/@parcel/"
    cp -R \
      node_modules/detect-libc \
      node_modules/is-extglob \
      node_modules/is-glob \
      node_modules/node-addon-api \
      node_modules/picomatch \
      "$out/parcel-watcher/node_modules/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    TEST_SHELL=${lib.escapeShellArg stdenv.shell} \
      NODE_PATH="$PWD/node_modules" \
      ELECTRON_RUN_AS_NODE=1 \
      ${electron_42}/bin/electron ${./test.cjs}

    WATCHER_PATH="$out/parcel-watcher/node_modules/@parcel/watcher" \
      ELECTRON_RUN_AS_NODE=1 \
      ${electron_42}/bin/electron -e \
        'require(process.env.WATCHER_PATH); console.log("parcel-watcher: ok")'

    runHook postInstallCheck
  '';

  meta = {
    description = "Linux native addons rebuilt for the ChatGPT desktop Electron ABI";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
