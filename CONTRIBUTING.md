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
