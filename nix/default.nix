{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libnotify,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  xdg-utils,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  system = stdenv.hostPlatform.system;
  package = source.packages.${system} or (throw "ChatGPT Desktop does not support ${system}");
in
stdenv.mkDerivation {
  pname = "chatgpt-desktop";
  inherit (source) version;

  src = fetchurl {
    inherit (package) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libsecret
    libusb1
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  # Qt shims and musl native modules are optional alternatives bundled beside
  # GTK/glibc implementations used by this package.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-aarch64.so.1"
    "libc.musl-x86_64.so.1"
  ];

  runtimeDependencies = [
    (lib.getLib libusb1)
    (lib.getLib systemd)
  ];

  unpackCmd = "dpkg-deb -x $curSrc .";
  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -R usr/lib/chatgpt "$out/lib/"
    cp -R usr/share/applications "$out/share/"
    cp -R usr/share/doc "$out/share/"
    cp -R usr/share/pixmaps "$out/share/"
    ln -s ../lib/chatgpt/codex-launcher "$out/bin/chatgpt"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/lib/chatgpt/codex-launcher" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}

    test -x "$out/lib/chatgpt/ChatGPT"
    test -x "$out/lib/chatgpt/resources/codex"
    test -x "$out/lib/chatgpt/resources/codex-code-mode-host"
    test -x "$out/lib/chatgpt/resources/rg"
    test -L "$out/bin/chatgpt"
    grep -Fq 'Exec=chatgpt %U' "$out/share/applications/chatgpt.desktop"
    ! grep -Fq -- '--no-sandbox' "$out/lib/chatgpt/codex-launcher"
  '';

  passthru.updateScript = ../scripts/update-source;

  meta = {
    description = "Official ChatGPT desktop application for Linux";
    homepage = "https://chatgpt.com/download/";
    downloadPage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "chatgpt";
    platforms = builtins.attrNames source.packages;
  };
}
