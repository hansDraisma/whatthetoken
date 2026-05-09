# Sparkle Key Custody

Sparkle update signing uses an EdDSA keypair separate from Apple Developer ID signing. The public key is embedded in `Info.plist` as `SUPublicEDKey`. The private key signs appcast update entries and must never be committed, logged, uploaded to GitHub Releases, stored in CI, or copied into `.context`.

## Custody Rules

- Generate keys only on the maintainer release machine.
- Store private material in the maintainer Keychain and one secure offline backup.
- Commit only the public key.
- Record the public key fingerprint in the release notes or maintainer release record.
- Rotate only with a tested migration plan because installed apps trust the embedded public key.

## Generation

Use Sparkle's official `generate_keys` tool from the resolved Sparkle package or release tooling. Run it only on the release machine.

After generation:

1. Copy only the printed public key.
2. Confirm it contains no whitespace.
3. Add it to `apps/mac/Packaging/Info.plist` as `SUPublicEDKey`.
4. Add `SUFeedURL = https://hansdraisma.github.io/whatthetoken/appcast.xml`.
5. Keep `SUEnableAutomaticChecks = false`.
6. Keep `SUAutomaticallyUpdate = false`.

Suggested guarded command:

```bash
PUBLIC_ED_KEY="$(pbpaste | tr -d '\n')"
test -n "$PUBLIC_ED_KEY"
printf '%s' "$PUBLIC_ED_KEY" | rg '^[A-Za-z0-9+/=]+$' >/dev/null
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' apps/mac/Packaging/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' apps/mac/Packaging/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :SUFeedURL string https://hansdraisma.github.io/whatthetoken/appcast.xml' apps/mac/Packaging/Info.plist
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_ED_KEY" apps/mac/Packaging/Info.plist
plutil -lint apps/mac/Packaging/Info.plist
```

## Appcast Publication

Generate `docs/appcast.xml` only after the notarized DMG and checksum have been published on GitHub Releases.

The appcast must:

- point at the public versioned DMG URL,
- include Sparkle's update signature,
- link to public release notes,
- avoid internal workspace paths,
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
