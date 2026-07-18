# Public V1 Release Checklist

This checklist is the maintainer path for the first direct-distribution Mac release.

Related runbooks:

- `docs/release/app-sandbox-compatibility-matrix.md`
- `docs/release/github-hosting-and-updates.md`
- `docs/release/release-notes-template.md`
- `docs/release/sparkle-key-custody.md`
- `docs/release/rollback-and-hotfix.md`

## Preconditions

- Use a clean checkout of `main`; signed release scripts enforce that the current branch is `main` and `HEAD` matches `origin/main`.
- Confirm the public version and monotonically increasing build number.
- Use `apps/mac/Scripts/bump-version.sh` for any version/build change before archiving.
- Confirm `apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is committed after resolving Xcode package dependencies.
- If `xcodebuild` fails to load `IDESimulatorFoundation` or reports first-launch content is missing, run `sudo xcodebuild -runFirstLaunch` on the signing machine before archive rehearsal.
- Confirm `DEVELOPER_ID_TEAM_ID` is set for the release signer.
- Confirm `DEVELOPER_ID_SIGNING_IDENTITY` is the exact Developer ID Application identity, including team suffix.
- Confirm `DEVELOPER_ID_APP_PROFILE_SPECIFIER` is set to an installed Developer ID provisioning profile for `com.whatthetoken.mac`.
- Confirm `DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER` is set to an installed Developer ID provisioning profile for `com.whatthetoken.mac.widget`.
- Confirm `SENTRY_DSN` is set to the public HTTPS DSN for the schema-drift project; the release script embeds it in the app.
- Confirm the Developer ID Application certificate does not expire within the next 30 days.
- Confirm `NOTARY_KEYCHAIN_PROFILE` exists in Keychain for `xcrun notarytool`.
- Confirm Gatekeeper assessments are enabled:

```bash
spctl --status | grep -F "assessments enabled"
```

- Confirm GitHub Pages is enabled from the `main` branch `/docs` folder.
- Confirm the public appcast URL is `https://hansdraisma.github.io/whatthetoken/appcast.xml`.
- Confirm the DMG URL pattern is `https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg`.
- Confirm Sparkle EdDSA private material is stored outside the repo, CI, and release hosting.
- Confirm no App Sandbox entitlement is enabled unless the connector compatibility matrix has passed.
- Confirm the archived app contains `CFBundleIconName = AppIcon` and `Contents/Resources/Assets.car`.

Maintainer note: use `hansDraisma` for GitHub repository URLs and `hansdraisma.github.io` for GitHub Pages URLs.

## Build And Test

```bash
pnpm install --frozen-lockfile
pnpm --filter @whatthetoken/core test
cd apps/mac
swift test
cd ../..
```

## Release Rehearsal

Review the release command chain without credentials:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
```

On an initialized Xcode installation, create an unsigned archive and smoke DMG:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

The unsigned smoke proves the Xcode target archives and the DMG script packages the app. It is not a public release artifact.

## Signed Tag

```bash
git status --porcelain
test -z "$(git status --porcelain)"
git fetch --tags origin main:refs/remotes/origin/main
test "$(git branch --show-current)" = "main"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
git tag -s v0.1.0 -m "WhatTheToken 0.1.0"
git verify-tag v0.1.0
test "$(git rev-parse HEAD)" = "$(git rev-list -n 1 refs/tags/v0.1.0)"
```

Do not push the tag until the signed rehearsal and local fresh-account smoke pass.

## Archive, Sign, Notarize, And Verify

```bash
: "${DEVELOPER_ID_TEAM_ID:?Set DEVELOPER_ID_TEAM_ID}"
: "${DEVELOPER_ID_SIGNING_IDENTITY:?Set DEVELOPER_ID_SIGNING_IDENTITY}"
: "${DEVELOPER_ID_APP_PROFILE_SPECIFIER:?Set DEVELOPER_ID_APP_PROFILE_SPECIFIER}"
: "${DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER:?Set DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE}"
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

Expected output:

- `apps/mac/.build/archive/WhatTheToken.xcarchive`
- `apps/mac/.build/export/WhatTheToken.app`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg.sha256`
- `apps/mac/.build/release-manifests/WhatTheToken-0.1.0-build-1.txt`

Required checks:

- `archive-release.sh` starts from a clean archive/export path, not stale `.build` outputs.
- The resolved export-options plist contains the maintainer `DEVELOPER_ID_TEAM_ID`.
- App is Developer ID signed.
- DMG is Developer ID signed before notarization.
- App and DMG code signatures contain secure timestamps.
- DMG is notarized and stapled.
- Gatekeeper accepts the exported app, DMG, and copied app from the mounted DMG.
- DMG mounts read-only and contains `WhatTheToken.app` plus an `Applications` symlink.
- Copied app contains `CFBundleIconName = AppIcon` and `Contents/Resources/Assets.car`.
- Copied app contains `Contents/PlugIns/WhatTheTokenWidget.appex`.
- `codesign --verify --deep --strict` passes on the embedded widget extension.
- Notarization succeeds with the widget extension present.
- Copied app binary contains both `arm64` and `x86_64`.
- Notary submission JSON and notary log JSON are saved under `apps/mac/.build/notary`.
- The generated checksum verifies locally:

```bash
( cd apps/mac/.build/dmg && shasum -a 256 -c WhatTheToken-0.1.0.dmg.sha256 )
```

If notarization is rejected, do not resubmit a modified binary with the same build number. Save the notary log, sanitize any shared excerpt, fix the cause, increment `CURRENT_PROJECT_VERSION`, and archive a new candidate.

## Fresh Account Install Smoke

- Copy the final DMG to `~/Downloads/WhatTheToken-0.1.0.dmg`.
- Add a download-style quarantine attribute as a local approximation:

```bash
DOWNLOADED_DMG="$HOME/Downloads/WhatTheToken-0.1.0.dmg"
cp apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg "$DOWNLOADED_DMG"
QUARANTINE_TIME="$(printf %x "$(date +%s)")"
xattr -w com.apple.quarantine "0081;$QUARANTINE_TIME;Safari;https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg" "$DOWNLOADED_DMG"
open "$DOWNLOADED_DMG"
```

- Install from the notarized DMG into `/Applications`.
- Launch from Finder.
- Confirm the menu bar item appears and the Dock icon stays hidden.
- Confirm settings open, quit works, and relaunch preserves settings.
- Confirm primary controls are reachable by keyboard and understandable with VoiceOver.
- Confirm launch at login defaults off and toggles only by explicit user action.
- Confirm Claude Code and Codex remain disconnected until explicit connection.
- Confirm disconnect removes provider cache.
- If `SUPublicEDKey` and `SUFeedURL` are embedded, confirm `Check for Updates` is visible; otherwise confirm the action is hidden or disabled.
- Confirm first launch makes no network request before explicit user action:

```bash
APP_PID="$(pgrep -x WhatTheTokenMac)"
test -n "$APP_PID"
NETWORK_LOG="$HOME/ReleaseArtifacts/WhatTheToken/first-launch-network.log"
mkdir -p "$(dirname "$NETWORK_LOG")"
: > "$NETWORK_LOG"
for _ in {1..12}; do
  lsof -nP -i -p "$APP_PID" >> "$NETWORK_LOG" 2>/dev/null || true
  sleep 5
done
test ! -s "$NETWORK_LOG"
```

- Confirm no background update network request occurs.
- If Sparkle metadata is embedded, confirm the only update network request happens after choosing `Check for Updates`.

After the GitHub Release is published, repeat one install smoke with the actual DMG downloaded through a browser. The `xattr` simulation is not a substitute for one real browser download.

## GitHub Release

- Push the signed tag only after the signed rehearsal and local fresh-account smoke pass:

```bash
git push origin v0.1.0
```

- Create a GitHub Release for `v0.1.0`.
- Attach `WhatTheToken-0.1.0.dmg`.
- Attach `WhatTheToken-0.1.0.dmg.sha256`.
- Download the published DMG and checksum from the GitHub Release and verify the checksum before announcement:

```bash
mkdir -p "$HOME/ReleaseArtifacts/WhatTheToken/published"
cd "$HOME/ReleaseArtifacts/WhatTheToken/published"
curl -fL -O https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg
curl -fL -O https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg.sha256
shasum -a 256 -c WhatTheToken-0.1.0.dmg.sha256
```

- Do not publish a separate `.app.zip` artifact for Public V1.
- Publish release notes that do not include sensitive diagnostics, internal workspace paths, raw provider output, prompts, responses, cookies, auth headers, tokens, or private key material.
- Include support guidance for sanitized crash reports and diagnostics; do not ask users to share raw provider files or credentials.

## Sparkle Appcast

Public V1 may include manual Sparkle checks when `SUPublicEDKey` and `SUFeedURL` are embedded. Automatic background checks and silent installs remain disabled.

If shipping a release with Sparkle intentionally inert, skip this section and remove or hide the in-app `Check for Updates` action for that release.

Generate the appcast only after the GitHub Release DMG asset exists:

Before committing appcast changes:

- Confirm `SUPublicEDKey` and `SUFeedURL` are intentionally set for the release channel.
- Confirm `SUFeedURL` is `https://hansdraisma.github.io/whatthetoken/appcast.xml`.
- Confirm the private EdDSA key stayed outside the repo, CI, and hosting machine.
- Confirm the appcast points only to published GitHub Release artifacts.
- Confirm Sparkle's `generate_appcast` tool is available through `SPARKLE_BIN_DIR`, `PATH`, or Xcode DerivedData package artifacts. The script auto-discovers all three locations; set `SPARKLE_BIN_DIR` only if discovery fails.

```bash
mkdir -p "$HOME/ReleaseArtifacts/WhatTheToken/updates"
cp apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg "$HOME/ReleaseArtifacts/WhatTheToken/updates/WhatTheToken-0.1.0.dmg"
apps/mac/Scripts/generate-appcast.sh \
  --updates-dir "$HOME/ReleaseArtifacts/WhatTheToken/updates" \
  --output docs/appcast.xml \
  --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/ \
  --release-notes-url https://github.com/hansDraisma/whatthetoken/releases/tag/v0.1.0
xmllint --noout docs/appcast.xml
grep -E "sparkle:edSignature|WhatTheToken-0.1.0.dmg|github.com/hansDraisma/whatthetoken/releases/download/v0.1.0" docs/appcast.xml
git add docs/appcast.xml
git commit -m "release: publish appcast for v0.1.0"
git push origin main
```

- Confirm a previous signed build updates to the new signed/notarized build after GitHub Pages publishes `docs/appcast.xml`.
- If the smoke has not passed, release notes must state GitHub Releases is the supported update path and must not market Sparkle as the primary update path.

## Credential-Gated Verification

The repository can verify metadata, script shape, dry-runs, and unsigned Swift builds. A real public release still requires maintainer-controlled Developer ID signing, notarization credentials, stapling against an accepted ticket, GitHub Release publication, GitHub Pages appcast publication, and Sparkle EdDSA signing.
