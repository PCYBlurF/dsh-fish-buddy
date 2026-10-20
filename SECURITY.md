# Security Policy

## Supported versions

The latest `0.1.x` release is supported with security fixes. Older releases are not.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

- Use GitHub's private vulnerability reporting: **Security → Report a vulnerability**
- Or contact the maintainer through the repository profile.

Please include the version, platform, reproduction steps, and any relevant logs without secrets (API keys, tokens, full credential files).

## Scope

- Electron renderer/CSP and `openExternal` URL handling
- Local credential reading (`~/.dsh/.credentials.yaml`) and state files
- macOS Gatekeeper/Electron installation behavior
- DSH plugin auto-start

## Not in scope / known limitations

- The macOS build is distributed as source and is **not code-signed/notarized** by Apple. macOS may quarantine the npm-installed Electron; see `mac/README.md`. Signing/notarization steps are documented in `mac/SIGNING.md`.
- The app reads local DSH session logs and credentials by design; it does not send them to third parties. The balance query only sends the API key to the selected provider's official endpoint.
