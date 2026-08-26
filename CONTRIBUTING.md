# Contributing

Keep official ChatGPT package files absent from Git. Never commit `.deb` files,
tokens, or resolved secrets.

Before submitting changes:

```console
nix flake check --print-build-logs
nix fmt -- --check .
```

For a new official Linux release:

```console
./scripts/update-source
git diff -- nix/source.json
nix flake check --print-build-logs
```

Updater verifies OpenAI's signed stable APT metadata against pinned repository
key and downloads x64 and ARM64 packages from versioned OpenAI URLs. It rejects
unexpected filenames, hashes, package names, architectures, and different
versions between architectures.
