# Sparkle Key Custody

Sparkle update signing uses an EdDSA keypair separate from Apple Developer ID signing. The public key is embedded in `Info.plist` as `SUPublicEDKey`. The private key signs appcast update entries and must never be committed, logged, uploaded to GitHub Releases, stored in CI, or copied into any agent scratch directory or AI session cache.

## Custody Rules

- Generate keys only on the maintainer release machine.
- Store private material in the maintainer Keychain and one secure offline backup.
- Commit only the public key.
- Record the public key fingerprint in the maintainer release record.
- Rotate only with a tested migration plan because installed apps trust the embedded public key.

## Release Metadata

The app embeds:

- `SUPublicEDKey`: the public EdDSA key
- `SUFeedURL`: `https://hansdraisma.github.io/whatthetoken-releases/appcast.xml`
- `SUEnableAutomaticChecks = false`
- `SUAutomaticallyUpdate = false`

The private source repository does not host the appcast. The canonical appcast is the root `appcast.xml` in the public `hansDraisma/whatthetoken-releases` distribution repository.

## Appcast Publication

Use `apps/mac/Scripts/publish-release.sh` after the signed source tag is pushed and the notarized DMG passes local verification. The script invokes Sparkle's `generate_appcast`, checks for the expected public versioned asset URL and `sparkle:edSignature`, publishes through the public distribution repository, waits for GitHub Pages, and verifies the downloaded assets.

The appcast must:

- point at a public versioned DMG URL,
- include Sparkle's update signature,
- link to public release notes,
- avoid internal paths and sensitive data,
- be reachable without GitHub authentication.

## Manual Update Smoke

Before announcing Sparkle support:

1. Install a previous signed/notarized build.
2. Publish the new DMG and appcast.
3. Wait for GitHub Pages to serve the new `appcast.xml`.
4. Choose `Check for Updates`.
5. Confirm only the explicit action contacts the appcast URL.
6. Complete the update.
7. Confirm the resulting app is signed, notarized, and reports the expected version/build.

If any step fails, keep GitHub Releases as the manual update path and cut a new build number after the fix.
