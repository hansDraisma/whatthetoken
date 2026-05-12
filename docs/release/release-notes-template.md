# Release Notes Template

Use this template for GitHub Releases. Do not include internal workspace paths, raw provider payloads, prompts, responses, cookies, auth headers, bearer tokens, provider session tokens, Sparkle private key material, or notarization credentials.

## WhatTheToken `<version>`

### Download

- `WhatTheToken-<version>.dmg`
- `WhatTheToken-<version>.dmg.sha256`

### Install

1. Download the DMG and checksum from this release.
2. Verify the checksum:

```bash
shasum -a 256 -c WhatTheToken-<version>.dmg.sha256
```

3. Open the DMG and drag `WhatTheToken.app` to `/Applications`.

### Changes

- Added:
- Changed:
- Fixed:

### Privacy And Security

- Provider credentials stay on device.
- WhatTheToken does not persist prompts, responses, cookies, auth headers, bearer tokens, provider session tokens, or raw provider payloads.
- Automatic update checks are disabled unless this release explicitly says otherwise.
- App Sandbox status:
- Notarization status:

### Known Issues

- 

### Verification

- Developer ID signed app:
- Build number, monotonically higher than the previous public release:
- Hardened runtime:
- Notarized and stapled DMG:
- Gatekeeper accepted copied app from mounted DMG:
- Fresh-account install smoke:
- Manual Sparkle update smoke, if applicable:

### Support

When reporting a problem, include the app version, macOS version, and sanitized screenshots or diagnostics. Do not send provider credentials, raw provider files, raw local databases, prompts, responses, cookies, auth headers, tokens, or private key material.
