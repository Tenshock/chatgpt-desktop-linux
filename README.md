# ChatGPT Desktop for Linux (Nix)

> See [Differences from `ilysenko/codex-desktop-linux`](#differences-from-ilysenkocodex-desktop-linux).
> **TL;DR:** this project stays closer to official ChatGPT Desktop sources.

Nix package running OpenAI's official Windows ChatGPT Desktop application on
`x86_64-linux` and `aarch64-linux`.

Project downloads user's own Microsoft Store MSIX, verifies its identity and
signature, replaces Windows Electron/native components with matching Linux
builds, and leaves official `app.asar` unchanged.

This is unofficial packaging. OpenAI does not provide or support this Linux
build. See [NOTICE.md](NOTICE.md).

## Status

- Source: official Microsoft Store package `OpenAI.Codex`.
- Current MSIX: `26.727.6591.0`.
- Electron: 42.
- Platforms: `x86_64-linux` and `aarch64-linux`.
- Electron sandbox: enabled.
- Tested on x86-64: packaged UI launch, Codex app-server connection, SQLite, PTY, HID,
  serial port, Git repository inotify events, GitHub CLI startup, Nix package,
  and NixOS toplevel build.
- ARM64: native package and CI build path; desktop runtime still needs validation
  on ARM64 hardware.

## How to Install

Nix flakes must be enabled. Source is proprietary and cannot be redistributed,
so first fetch user's official copy into local Nix store:

```console
nix run github:Tenshock/chatgpt-desktop-linux#fetch
```

Run without installing:

```console
nix run github:Tenshock/chatgpt-desktop-linux
```

If Microsoft Store already moved to a newer version than repository metadata,
fetch command stops with a clear version mismatch. Wait for repository update;
old revisions may no longer be bootstrapable because Store serves only current
package.

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

On the first installation on a machine, add the proprietary MSIX to its local
Nix store, then rebuild. Later rebuilds need only `nixos-rebuild` while that
store path still exists:

```console
nix run github:Tenshock/chatgpt-desktop-linux#fetch
sudo nixos-rebuild switch --flake .#your-hostname
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

## What Package Changes

Package preserves official application archive byte-for-byte. Linux adaptation
happens around it:

- true packaged Electron directory layout;
- Nixpkgs Electron 42 runtime;
- rebuilt Linux `better-sqlite3`, `node-pty`, `node-hid`, and serial-port addons;
- exact `@parcel/watcher` 2.5.6 Linux binding declared by official app;
- version-matched official Linux `codex`, `codex-code-mode-host`, and `rg`
  helpers (MSIX copies on x86-64, OpenAI Codex release package on ARM64);
- Wayland auto-selection and libsecret password-store flags;
- desktop entry, icon, and `codex://` protocol association.

## Differences from ilysenko/codex-desktop-linux

This project aims to stay as close as possible to the official
ChatGPT Desktop version: it preserves the official application archive
byte-for-byte and limits changes to the Linux runtime and native components
required around it.

A notable security difference is sandbox policy: this project keeps Electron's
sandbox enabled and fails its package check if `--no-sandbox` appears in the
launcher. The compared project's current launcher disables it. Sandbox process
isolation reduces impact from a compromised renderer, but cannot make either
unofficial Linux package equivalent to an OpenAI-supported release.

[ilysenko/codex-desktop-linux](https://github.com/ilysenko/codex-desktop-linux)
is larger Linux adaptation project. Both projects are unofficial and currently
package same internal application generation, but goals differ.

| Area                | This project                                          | `ilysenko/codex-desktop-linux`                                    |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------- |
| Official source     | Windows Microsoft Store MSIX                          | macOS DMG                                                         |
| Application archive | Kept byte-identical                                   | Extracted, patched, repacked                                      |
| Goal                | Minimal Linux adaptation around official Windows app  | Linux-first compatibility and extra features                      |
| Codex CLI           | Version-matched official Linux helpers                | External CLI required/configurable                                |
| Git watching        | Official Parcel watcher with Linux binding            | Upstream path plus optional bounded/shallow watcher patches       |
| Wayland             | Direct Electron auto hint                             | XWayland/Wayland detection and GPU workaround launcher            |
| Sandbox             | Enabled                                               | Launcher currently uses `--no-sandbox`                            |
| Computer Use        | Official resources retained; Linux control unverified | Dedicated Rust Linux backend and optional UI                      |
| Plugins             | Official MSIX payload retained                        | Selected plugins staged and Linux-patched                         |
| Linux extras        | None                                                  | Dictation, AppShots, remote control, Codex Micro, UI tweaks, more |
| Nix modules         | Small NixOS/Home Manager install modules              | Rich modules with feature and service options                     |
| Architectures       | `x86_64-linux`, `aarch64-linux`                       | `x86_64-linux`, `aarch64-linux`                                   |

Choose this project for closest Windows-app fidelity, fewer application-code
changes, and enabled Electron sandbox. Choose ilysenko project for broader
Linux desktop integration, Computer Use support, or optional features.

Detailed comparison sources:

- [ilysenko architecture](https://github.com/ilysenko/codex-desktop-linux/blob/main/docs/architecture.md)
- [ilysenko feature matrix](https://github.com/ilysenko/codex-desktop-linux#feature-matrix)
- [ilysenko Nix documentation](https://github.com/ilysenko/codex-desktop-linux/blob/main/docs/nix.md)

## Updating Source Metadata

Maintainers:

```console
./scripts/update-source
git diff -- nix/source.json
nix flake check --print-build-logs
```

Updater downloads only from Microsoft Store delivery hosts and verifies:

- APPX identity, publisher, architecture, version, and display name;
- package signature and timestamp chain against pinned Microsoft roots;
- APPX block hashes through `osslsigncode`;
- Owl runtime compatibility identifier;
- hashes of bundled x86-64 Codex helpers used to select the matching ARM64
  OpenAI Codex release;
- native-module versions expected by Linux rebuild.

Changed runtime, Codex helper, or native-module versions intentionally stop
automated update. They require compatibility audit and explicit metadata
change.

## Development

```console
nix run .#fetch
nix flake check --print-build-logs
nix fmt -- --check .
```

`nix run .#fetch` adds proprietary MSIX only to local Nix store. Do not commit,
publish, attach, or cache MSIX or final ChatGPT package.

## Known Limitations

- No official Linux support from OpenAI.
- New users depend on current Microsoft Store version matching repository.
- ARM64 desktop runtime has not yet been validated on physical ARM64 hardware.
- Computer Use and all bundled plugins lack full Linux end-to-end validation.
- Nix store is immutable; plugins attempting to update their packaged files may
  fail and need future writable-staging adaptation.
- OpenAI can change package format, signatures, native dependencies, or service
  behavior at any time.

## License

Repository packaging code: MIT. Official application and third-party software:
their respective licenses and terms. See [LICENSE](LICENSE) and
[NOTICE.md](NOTICE.md).
