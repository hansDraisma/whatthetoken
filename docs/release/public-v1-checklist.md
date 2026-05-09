# Public V1 Release Checklist

This checklist is the maintainer path for the first direct-distribution Mac release.

## Preconditions

- Use a clean checkout of `main`.
- Confirm the public version and monotonically increasing build number.
- Confirm `DEVELOPER_ID_TEAM_ID` is set for the release signer.
- Confirm `NOTARY_KEYCHAIN_PROFILE` exists in Keychain for `xcrun notarytool`.
- Confirm Sparkle EdDSA private material is stored outside the repo and release hosting.
- Confirm no App Sandbox entitlement is enabled unless the connector compatibility matrix has passed.

## Build And Test

```bash
pnpm install --frozen-lockfile
pnpm --filter @whatthetoken/core test
cd apps/mac
swift test
cd ../..
```

## Archive And Export

```bash
apps/mac/Scripts/archive-release.sh --version 0.1.0 --build 1
```

Expected output:

- `apps/mac/.build/archive/WhatTheToken.xcarchive`
- `apps/mac/.build/export/WhatTheToken.app`

## DMG

```bash
apps/mac/Scripts/create-dmg.sh --version 0.1.0
```

Expected output:

- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg`

## Notarize And Staple

```bash
apps/mac/Scripts/notarize-dmg.sh --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg
```

The script submits the DMG with `notarytool`, waits for acceptance, staples the ticket, and validates the staple.

## Verify Artifacts

```bash
apps/mac/Scripts/verify-release-artifacts.sh \
  --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg \
  --app apps/mac/.build/export/WhatTheToken.app
```

Required checks:

- `codesign --verify --deep --strict --verbose=2` passes for the app.
- Gatekeeper accepts the app.
- Stapler validates the DMG.
- Gatekeeper accepts the DMG.
- A `.sha256` checksum file is generated for the DMG.

## GitHub Release

- Create a draft GitHub Release for the tag.
- Attach the notarized DMG and checksum.
- Publish release notes that do not include sensitive diagnostics, internal workspace paths, raw provider output, prompts, responses, cookies, auth headers, tokens, or private key material.
- Install the attached DMG on a fresh macOS account and smoke test launch, menu bar display, settings persistence, connector opt-in, disconnect, quit, and relaunch.

## Sparkle Appcast

Public V1 keeps automatic Sparkle checks disabled. Generate an appcast entry only after a signed old-build to signed new-build update smoke test passes.

```bash
apps/mac/Scripts/generate-appcast.sh \
  --updates-dir /path/to/public-updates \
  --download-url-prefix https://example.com/whatthetoken/releases/
```

Before publishing appcast changes:

- Confirm `SUPublicEDKey` and `SUFeedURL` are intentionally set for the release channel.
- Confirm the private EdDSA key stayed outside the repo and hosting machine.
- Confirm the appcast URL is stable HTTPS infrastructure controlled by the project.
- Confirm the update archive is signed and the appcast points only to published artifacts.

## Credential-Gated Verification

The repository can verify metadata, script shape, dry-runs, and unsigned Swift builds. A real public release still requires maintainer-controlled Developer ID signing, notarization credentials, stapling against an accepted ticket, and Sparkle EdDSA signing.
