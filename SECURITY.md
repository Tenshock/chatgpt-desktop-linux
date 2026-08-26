# Security

Report packaging vulnerabilities privately through GitHub Security Advisories.
Do not include ChatGPT credentials, GitHub tokens, 1Password references, logs
containing secrets, or proprietary application binaries in reports.

Packaging security properties:

- source URLs restricted to OpenAI's documented Linux package host;
- OpenAI APT metadata verified with pinned repository key fingerprint
  `3BFA0E4AE8B8CC16A2D9BA684A3B4A566C4660E4`;
- x64 and ARM64 packages pinned by cryptographic hash;
- repository hash, package name, architecture, and matching version checked by
  updater;
- official application payload retained, except Nix ELF/RPATH and script
  interpreter patching required to run on NixOS;
- no `--no-sandbox` launcher flag added.

Do not upload official `.deb` files or final ChatGPT packages to public releases
or binary caches unless OpenAI's terms explicitly permit redistribution.
