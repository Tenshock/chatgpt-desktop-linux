# Security

Report packaging vulnerabilities privately through GitHub Security Advisories.
Do not include ChatGPT credentials, GitHub tokens, 1Password references, logs
containing secrets, or proprietary application binaries in reports.

Security properties intentionally enforced by package:

- Microsoft Store delivery host allowlist.
- MSIX identity, publisher, architecture, version, signature, timestamp, and
  APPX block verification.
- Pinned source and dependency hashes.
- Electron sandbox remains enabled.
- Official `app.asar` remains byte-identical.

No final ChatGPT Desktop package or MSIX should be uploaded to public releases
or binary caches.
