# ChatGPT Desktop for Linux (Nix)

Nix package for OpenAI's official ChatGPT desktop application for Linux.

OpenAI provides Linux preview packages for Ubuntu, Debian, and Fedora on x64
and ARM64. This flake repackages official `.deb` files for NixOS without
changing application code or replacing bundled components.

## Status

- Source: official OpenAI Linux `.deb` package.
- Version: `26.820.60940`.
- Platforms: `x86_64-linux` and `aarch64-linux`.
- Application payload: unchanged except Nix ELF/RPATH and script-interpreter
  paths.
- Updates: pinned by hash and applied through flake updates.

OpenAI lists Ubuntu 24.04/26.04, Debian 13, and Fedora 43/44 as supported
desktop distributions. NixOS is not formally supported; this repository is an
independent Nix packaging layer.

See [official Linux documentation](https://learn.chatgpt.com/docs/linux/linux-app)
and [ChatGPT downloads](https://chatgpt.com/download/).

## Run

```console
nix run github:Tenshock/chatgpt-desktop-linux
```

No separate source-fetch step is required. Official packages are public and
downloaded directly from OpenAI's `persistent.oaistatic.com` host.

### NixOS module

Add input:

```nix
{
  inputs.chatgpt-desktop-linux = {
    url = "github:Tenshock/chatgpt-desktop-linux";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Import module and enable package:

```nix
{
  imports = [ inputs.chatgpt-desktop-linux.nixosModules.default ];
  programs.chatgptDesktop.enable = true;
}
```

### Home Manager module

```nix
{
  imports = [ inputs.chatgpt-desktop-linux.homeManagerModules.default ];
  programs.chatgptDesktop.enable = true;
}
```

### Direct package

```nix
environment.systemPackages = [
  inputs.chatgpt-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

## Packaging

Package keeps OpenAI's Linux layout under `lib/chatgpt`, including:

- official Electron/Chromium runtime;
- official Linux native modules;
- bundled `codex`, `codex-code-mode-host`, and `rg` executables;
- bundled plugins and Computer Use resources;
- official desktop entry and icon.

Nix packaging changes only ELF interpreters/RPATHs, launcher environment,
installation paths, and dependency references required by NixOS. It does not
install OpenAI's Debian APT repository or AppArmor profile.

Official documentation says Computer Use is not yet available in Linux
preview. Native Wayland is experimental; default behavior uses XWayland when
available. Launch explicitly with native Wayland using:

```console
chatgpt --ozone-platform=wayland
```

## Updating

```console
./scripts/update-source
nix flake check --print-build-logs
nix fmt -- --check .
```

Updater verifies OpenAI's signed stable APT metadata against pinned repository
key, downloads both versioned official `.deb` files, verifies repository hash,
package name, architecture, and matching version, then records their Nix hashes.

## License

Repository packaging code: MIT. ChatGPT application and bundled third-party
software: their respective licenses and terms. See [NOTICE.md](NOTICE.md).
