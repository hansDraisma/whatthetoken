# Rollback And Hotfix

Release artifacts are immutable from the user's point of view. If a candidate reaches the public distribution repository, appcast publication, or user installation, do not replace it with a different binary under the same version/build.

## Build Number Rules

- `CFBundleVersion` must increase for every public candidate.
- Never reuse a build number after notarization rejection, Gatekeeper failure, appcast publication, or public download.
- Use `apps/mac/Scripts/bump-version.sh --version <version> --build <new-build>` before archiving a replacement candidate.

## Notarization Rejection Recovery

1. Keep the rejected notary submit JSON and log under `apps/mac/.build/notary`.
2. Sanitize any excerpt before sharing.
3. Fix the cause.
4. Increment `CURRENT_PROJECT_VERSION`.
5. Re-archive from a clean source tree.
6. Re-run signed rehearsal.

Do not resubmit a modified binary with the same build number.

## Bad Public Release Before Appcast

If a DMG is attached to the public GitHub Release but the public `appcast.xml` has not been updated:

1. If no user could have downloaded the asset, return the GitHub Release to draft or delete the bad asset.
2. If any user may have downloaded the asset, increment the build number before publishing a replacement.
3. Publish a corrected release.
4. Keep the appcast pointed only at the corrected artifact.

## Bad Appcast

If the public `appcast.xml` points at a bad artifact:

1. Patch the public distribution repository's root `appcast.xml` immediately so it points at the last known-good artifact.
2. Confirm GitHub Pages serves the corrected appcast.
3. If users may have updated, publish a higher-build hotfix.
4. Do not point the appcast at a lower build.

## Hotfix Flow

```bash
apps/mac/Scripts/bump-version.sh --version <version> --build <higher-build>
pnpm install --frozen-lockfile
pnpm --filter @whatthetoken/core test
cd apps/mac && swift test && cd ../..
apps/mac/Scripts/rehearse-release.sh --version <version> --build <higher-build> --mode signed
```

Push the new signed source tag, then run `apps/mac/Scripts/publish-release.sh` with the matching version/build and sanitized release notes. Verify a manual Sparkle update from the previous public build.
