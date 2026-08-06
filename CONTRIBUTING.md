# Contributing

Keep application payload absent from Git. Never commit `.msix` files, tokens,
or resolved secrets.

Before submitting changes:

```console
nix run .#fetch
nix flake check --print-build-logs
nix fmt -- --check .
```

For a new Microsoft Store release:

```console
./scripts/update-source
git diff -- nix/source.json
nix flake check --print-build-logs
```

Updater deliberately rejects changes to Owl runtime or native-module versions.
When that happens, audit compatibility, update pinned values deliberately, and
run application smoke tests before publishing metadata.

After auditing an Owl runtime change, accept and record it explicitly:

```console
./scripts/update-source --override
```

This flag accepts the Owl runtime identifier and all three bundled Codex
resource hashes as one audited compatibility override. It still verifies the
complete signed MSIX and all other compatibility pins before updating
`nix/source.json`.

This does not change the pinned Codex release or architecture-specific package
hashes. Audit and update those separately when the bundled Codex version
changes.
