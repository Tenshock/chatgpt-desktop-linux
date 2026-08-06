{
  lib,
  stdenvNoCC,
  asar,
  binutils,
  callPackage,
  electron_42,
  file,
  imagemagick,
  jq,
  libxml2,
  makeDesktopItem,
  makeWrapper,
  openssl,
  osslsigncode,
  requireFile,
  systemdMinimal,
  unzip,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  hostPlatform = stdenvNoCC.hostPlatform;
  isAarch64 = hostPlatform.isAarch64;
  npmArch =
    if hostPlatform.isx86_64 then
      "x64"
    else if isAarch64 then
      "arm64"
    else
      throw "ChatGPT Desktop does not support ${hostPlatform.system}";
  elfArchitecture = if isAarch64 then "ARM aarch64" else "x86-64";
  roots = callPackage ./microsoft-roots.nix { };
  nativeModules = callPackage ./native-modules { };
  codexPackage = callPackage ./codex-package.nix { };
  updater = callPackage ./updater.nix { };

  msix = requireFile {
    name = source.fileName;
    inherit (source) sha256;
    message = ''
      ChatGPT Desktop is not redistributable. Fetch and verify the official
      Microsoft Store MSIX locally with:

        nix run github:Tenshock/chatgpt-desktop-linux#fetch
    '';
  };

  desktopItem = makeDesktopItem {
    name = "chatgpt";
    exec = "chatgpt %U";
    icon = "chatgpt";
    desktopName = "ChatGPT";
    genericName = "AI assistant and coding agent";
    comment = "Chat, Work, and Codex desktop application";
    categories = [
      "Network"
      "Development"
    ];
    startupWMClass = "ChatGPT";
    mimeTypes = [ "x-scheme-handler/codex" ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "chatgpt-desktop";
  inherit (source) version;

  src = msix;
  sourceRoot = ".";

  nativeBuildInputs = [
    binutils
    asar
    file
    imagemagick
    jq
    libxml2
    makeWrapper
    openssl
    osslsigncode
    unzip
  ];

  unpackPhase = ''
    runHook preUnpack

    bash ${./verify-msix.sh} \
      "$src" \
      ${roots.root2010} \
      ${roots.root2011} \
      ${lib.escapeShellArg source.version} \
      ${lib.escapeShellArg source.identity} \
      ${lib.escapeShellArg source.publisher} \
      ${lib.escapeShellArg source.compatibility.owlRuntimeArchiveSha} \
      ${lib.escapeShellArg source.compatibility.nativeModules."better-sqlite3"} \
      ${lib.escapeShellArg source.compatibility.nativeModules."node-pty"} \
      ${lib.escapeShellArg source.compatibility.nativeModules."node-hid"} \
      ${lib.escapeShellArg source.compatibility.nativeModules."@serialport/bindings-cpp"} \
      ${lib.escapeShellArg source.compatibility.codex.bundledX64Sha256.codex} \
      ${lib.escapeShellArg source.compatibility.codex.bundledX64Sha256."codex-code-mode-host"} \
      ${lib.escapeShellArg source.compatibility.codex.bundledX64Sha256.rg}

    unzip -q "$src" 'app/resources/*'

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    while IFS= read -r -d "" path; do
      parent="''${path%/*}"
      name="''${path##*/}"
      decoded="''${name//%40/@}"
      decoded="''${decoded//%2B/+}"
      decoded="''${decoded//%24/\$}"
      if [[ $decoded != "$name" ]]; then
        mv -- "$path" "$parent/$decoded"
      fi
    done < <(find app/resources -depth -print0)

    source_asar_hash=$(sha256sum app/resources/app.asar | cut -d ' ' -f 1)

    mkdir -p "$out/lib/chatgpt"
    cp -R app/resources "$out/lib/chatgpt/resources"
    chmod -R u+w "$out/lib/chatgpt/resources"
    resources="$out/lib/chatgpt/resources"

    cp -R ${nativeModules}/parcel-watcher/node_modules "$resources/"

    electron_dir=${electron_42.unwrapped}/libexec/electron
    cp --reflink=auto "$electron_dir/electron" "$out/lib/chatgpt/chatgpt"
    chmod u+w "$out/lib/chatgpt/chatgpt"
    for runtime_file in "$electron_dir"/*; do
      runtime_name="''${runtime_file##*/}"
      case "$runtime_name" in
        electron | resources) continue ;;
      esac
      ln -s "$runtime_file" "$out/lib/chatgpt/$runtime_name"
    done

    substitute ${electron_42}/bin/electron "$out/lib/chatgpt/electron-wrapper" \
      --replace-fail \
        "$electron_dir/electron" \
        "$out/lib/chatgpt/chatgpt"
    chmod +x "$out/lib/chatgpt/electron-wrapper"

    install -Dm755 \
      ${nativeModules}/better-sqlite3/better_sqlite3.node \
      "$resources/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
    install -Dm755 \
      ${nativeModules}/node-pty/pty.node \
      "$resources/app.asar.unpacked/node_modules/node-pty/build/Release/pty.node"
    install -Dm755 \
      ${nativeModules}/node-hid/HID.node \
      "$resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/node-hid/build/Release/HID.node"
    install -Dm755 \
      ${nativeModules}/serialport/bindings.node \
      "$resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/@serialport/bindings-cpp/build/Release/bindings.node"

    rm -f \
      "$resources/app.asar.unpacked/node_modules/node-pty/build/Release/conpty.node" \
      "$resources/app.asar.unpacked/node_modules/node-pty/build/Release/conpty_console_list.node" \
      "$resources/codex.exe" \
      "$resources/codex-code-mode-host.exe" \
      "$resources/codex-command-runner.exe" \
      "$resources/codex-windows-sandbox-setup.exe" \
      "$resources/rg.exe"

    ${lib.optionalString isAarch64 ''
      install -Dm755 ${codexPackage}/bin/codex "$resources/codex"
      install -Dm755 \
        ${codexPackage}/bin/codex-code-mode-host \
        "$resources/codex-code-mode-host"
      install -Dm755 ${codexPackage}/codex-path/rg "$resources/rg"
    ''}

    chmod +x \
      "$resources/codex" \
      "$resources/codex-code-mode-host" \
      "$resources/rg"

    magick "$resources/icon-chatgpt.ico[7]" "$resources/icon-chatgpt.png"
    install -Dm644 \
      "$resources/icon-chatgpt.png" \
      "$out/share/icons/hicolor/256x256/apps/chatgpt.png"

    mkdir -p "$out/share/applications"
    cp ${desktopItem}/share/applications/chatgpt.desktop \
      "$out/share/applications/chatgpt.desktop"

    makeWrapper "$out/lib/chatgpt/electron-wrapper" "$out/bin/chatgpt" \
      --set CODEX_ELECTRON_RESOURCES_PATH "$resources" \
      --prefix PATH : ${lib.makeBinPath [ systemdMinimal ]} \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--password-store=gnome-libsecret"

    installed_asar_hash=$(sha256sum "$resources/app.asar" | cut -d ' ' -f 1)
    [[ $source_asar_hash == "$installed_asar_hash" ]]

    for helper in codex codex-code-mode-host rg; do
      file "$resources/$helper" | grep -Eq 'ELF 64-bit.*${elfArchitecture}'
    done
    for addon in \
      "$resources/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
      "$resources/app.asar.unpacked/node_modules/node-pty/build/Release/pty.node" \
      "$resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/node-hid/build/Release/HID.node" \
      "$resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/@serialport/bindings-cpp/build/Release/bindings.node"; do
      file "$addon" | grep -Eq 'ELF 64-bit.*${elfArchitecture}'
    done
    ! grep -Fq -- '--no-sandbox' "$out/bin/chatgpt"
    grep -Fq "$out/lib/chatgpt/chatgpt" "$out/lib/chatgpt/electron-wrapper"
    ! grep -Fq "$resources/app.asar" "$out/bin/chatgpt"
    test -f "$resources/node_modules/@parcel/watcher/index.js"
    file "$resources/node_modules/@parcel/watcher-linux-${npmArch}-glibc/watcher.node" \
      | grep -Eq 'ELF 64-bit.*${elfArchitecture}'

    runHook postInstall
  '';

  preferLocalBuild = true;
  allowSubstitutes = false;
  dontStrip = true;

  passthru = {
    inherit nativeModules updater;
    updateScript = ./update;
  };

  meta = {
    description = "Unofficial Linux package of OpenAI's official ChatGPT desktop application";
    homepage = "https://github.com/Tenshock/chatgpt-desktop-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "chatgpt";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    hydraPlatforms = [ ];
  };
}
