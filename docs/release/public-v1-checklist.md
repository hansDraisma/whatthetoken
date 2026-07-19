# Public V1 Release Checklist

This is the maintainer path for the first direct-distribution Mac release. Customers use only `hansDraisma/whatthetoken-releases`; the source repository remains private.

Related runbooks:

- `docs/release/app-sandbox-compatibility-matrix.md`
- `docs/release/github-hosting-and-updates.md`
- `docs/release/release-notes-template.md`
- `docs/release/sparkle-key-custody.md`
- `docs/release/rollback-and-hotfix.md`

## Preconditions

- Use a clean checkout of `main`; release scripts enforce that the current branch is `main` and `HEAD` matches `origin/main`.
- Confirm the public version and monotonically increasing build number.
- Confirm `Package.resolved` is committed.
- Confirm the Developer ID Application certificate has at least 30 days remaining.
- Set `DEVELOPER_ID_TEAM_ID` and the exact `DEVELOPER_ID_SIGNING_IDENTITY`.
- Confirm both entitlements use `3U98C8T3DT.com.whatthetoken.mac`. Apple supports Team-ID-prefixed macOS app groups without provisioning profiles, while `group.`-prefixed identifiers require profiles. See [Accessing app group containers](https://developer.apple.com/documentation/xcode/accessing-app-group-containers).
- Set `SENTRY_DSN` to the public HTTPS DSN for sanitized schema-drift monitoring, or set `RELEASE_WITHOUT_SENTRY=1` to make an explicit telemetry-free release. Never set both.
- Confirm `NOTARY_KEYCHAIN_PROFILE` exists in Keychain for `xcrun notarytool`.
- Confirm Sparkle EdDSA private material is in the maintainer Keychain and an offline backup, never the repo, CI, hosting, or scratch storage.
- Confirm Gatekeeper is enabled with `spctl --status`.
- Confirm no App Sandbox entitlement is enabled unless the connector compatibility matrix has passed.
- Confirm the public repository is `https://github.com/hansDraisma/whatthetoken-releases`.
- Confirm immutable releases and private vulnerability reporting are enabled there.
- Confirm the customer page is `https://hansdraisma.github.io/whatthetoken-releases/`.
- Confirm `SUFeedURL` is `https://hansdraisma.github.io/whatthetoken-releases/appcast.xml`.
- Confirm the DMG URL pattern is `https://github.com/hansDraisma/whatthetoken-releases/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg`.

## Build And Test

```bash
pnpm install --frozen-lockfile
pnpm --filter @whatthetoken/core test
cd apps/mac
swift test
cd ../..
```

Run the full non-secret release preflight before building. It verifies clean-source provenance, version metadata, Developer ID certificate lifetime, Team-ID app group entitlements, the explicit Sentry/telemetry-free choice, notarization access, the Sparkle keypair, GitHub authentication, immutable releases, and the public appcast without printing credentials:

```bash
apps/mac/Scripts/release-preflight.sh --version 0.1.0 --build 1
```

Review release commands without credentials, then exercise the unsigned archive:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

The unsigned smoke is never a public artifact.

## Signed Candidate

```bash
: "${DEVELOPER_ID_TEAM_ID:?Set DEVELOPER_ID_TEAM_ID}"
: "${DEVELOPER_ID_SIGNING_IDENTITY:?Set DEVELOPER_ID_SIGNING_IDENTITY}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE}"
# Public V1 ships telemetry-free. For a future monitored release, unset this
# flag and set SENTRY_DSN to the public HTTPS project DSN instead.
unset SENTRY_DSN
export RELEASE_WITHOUT_SENTRY=1
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

The signed rehearsal verifies clean `main` provenance but intentionally permits the release tag to be absent. The publication path does not: it requires the signed tag created after the local candidate smoke below.

Required outputs:

- `apps/mac/.build/archive/WhatTheToken.xcarchive`
- `apps/mac/.build/export/WhatTheToken.app`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg.sha256`
- `apps/mac/.build/release-manifests/WhatTheToken-0.1.0-build-1.txt`

Confirm the app and DMG have Developer ID signatures with secure timestamps, the DMG is notarized and stapled, Gatekeeper accepts the exported and mounted app, the widget has the same team and App Group entitlement, the binary contains `arm64` and `x86_64`, and the checksum verifies.

If notarization fails, sanitize and retain the log, fix the cause, increment the build, and create a new candidate. Never reuse a rejected or public build number.

## Local Install Smoke

- Install the notarized DMG into `/Applications` through Finder.
- Launch from Finder and verify the menu bar item, hidden Dock icon, Settings, Quit, and persistence.
- Verify keyboard access and VoiceOver labels.
- Verify launch at login defaults off and changes only on explicit action.
- Verify Claude Code and Codex remain disconnected until explicit connection.
- Verify disconnect removes the provider cache.
- Verify there is no first-launch or background-update network request.
- Verify the only update request occurs after `Check for Updates`.
- Verify the privacy link opens the public distribution repository's notice.

Repeat the smoke once with the actual public DMG downloaded through a browser after publication.

## Signed Source Tag

Only after the signed candidate and local install smoke pass:

```bash
git status --porcelain
test -z "$(git status --porcelain)"
git fetch --tags origin main:refs/remotes/origin/main
test "$(git branch --show-current)" = main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
git tag -s v0.1.0 -m "WhatTheToken 0.1.0"
git verify-tag v0.1.0
git push origin v0.1.0
```

## Public Distribution

Prepare sanitized notes from `docs/release/release-notes-template.md`, preview the publication, then publish:

```bash
apps/mac/Scripts/publish-release.sh \
  --version 0.1.0 \
  --build 1 \
  --notes "$HOME/ReleaseArtifacts/WhatTheToken/release-notes-0.1.0.md" \
  --dry-run

apps/mac/Scripts/publish-release.sh \
  --version 0.1.0 \
  --build 1 \
  --notes "$HOME/ReleaseArtifacts/WhatTheToken/release-notes-0.1.0.md"
```

The publisher refuses to overwrite an existing release. It re-verifies provenance, signatures, notarization, Gatekeeper, appcast signature, public Pages publication, and downloaded checksums.

If the command is interrupted after creating the draft or publishing the release, repeat the same command with `--resume`. Resume mode may upload an asset that is missing from a draft, then verifies all hosted artifacts match the local candidate before completing publication; it never replaces an existing asset.

Do not publish a separate `.app.zip`. Do not include private source paths, raw provider output, prompts, responses, cookies, auth headers, tokens, private-key material, or unsanitized diagnostics in release notes or public issues.

## Public Verification

```bash
gh release view v0.1.0 --repo hansDraisma/whatthetoken-releases
curl -fL https://hansdraisma.github.io/whatthetoken-releases/
curl -fL https://hansdraisma.github.io/whatthetoken-releases/appcast.xml
```

- Download the public DMG and checksum and verify them again.
- Confirm the release is not a draft or prerelease and is marked latest.
- Confirm the appcast contains `sparkle:edSignature` and only the versioned public DMG URL.
- Confirm a previous signed build updates to the new signed/notarized build.
- If the smoke has not passed, release notes must state GitHub Releases is the supported update path and must not market Sparkle as the primary update path.
- Confirm private vulnerability reporting and safe public issue forms are enabled.

Verify the exact public assets and install the customer build on the release Mac. Existing `/Applications/WhatTheToken.app` is moved to a timestamped, recoverable backup before the verified app is installed:

```bash
apps/mac/Scripts/install-published-release.sh --version 0.1.0 --build 1
apps/mac/Scripts/install-published-release.sh --version 0.1.0 --build 1 --install
```

If shipping a release with Sparkle intentionally inert, skip the update smoke and hide the in-app action. If `SUPublicEDKey` and `SUFeedURL` are embedded, confirm `Check for Updates` is visible and manual-only.

## Credential-Gated Boundary

The repository can verify metadata, script shape, dry-runs, and unsigned Swift builds. A real public release requires the maintainer-controlled Developer ID certificate, notarization credentials, an explicit Sentry or telemetry-free choice, Sparkle EdDSA signing, public release publication, and an installed-artifact smoke. Never weaken these gates to publish an ad-hoc build.
